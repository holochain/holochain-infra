use anyhow::Ok;
use log::{info, trace, warn};
use std::collections::HashMap;

/*
set -Eu -o pipefail

env

ls -lha ''${SECRET_cacheHoloHost2public}
cat ''${SECRET_cacheHoloHost2public}

echo ''${SECRET_cacheHoloHost2public} > public-key
cat public-key

*/
fn main() -> anyhow::Result<()> {
    env_logger::builder()
        .filter_level(log::LevelFilter::Debug)
        .init();

    let build_info = business::BuildInfo::from_env();

    let _ = business::check_owners(build_info.try_owners()?);

    let (signing_key_file, copy_destination) =
        if let Some(info) = business::may_get_signing_key_and_copy_destination(&build_info)? {
            info
        } else {
            warn!("got no signing/uploading credentials, exiting.");
            return Ok(());
        };
    let signing_key_file_path = signing_key_file.path().to_str().ok_or_else(|| {
        anyhow::anyhow!(
            "could not convert {} (lossy) to string",
            signing_key_file.path().to_string_lossy()
        )
    })?;

    // TODO: read the attribute name from the environment
    let store_path = "./result";

    // sign the store path
    util::nix_cmd_helper(&[
        "store",
        "sign",
        "--verbose",
        "--recursive",
        "--key-file",
        signing_key_file_path,
        store_path,
    ])?;
    info!("successfully signed store path {store_path}");

    // copy the store path
    util::nix_cmd_helper(&["copy", "--verbose", "--to", &copy_destination, store_path])?;
    info!("successfully pushed store path {store_path}");

    Ok(())
}

mod util {
    use std::process::Stdio;

    use anyhow::{bail, Context};

    pub(crate) fn nix_cmd_helper(args: &[&str]) -> anyhow::Result<()> {
        let mut cmd = std::process::Command::new("nix");
        cmd.args(args)
            // pass stdio through so it becomes visible in the log
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit());

        let context = format!("running {cmd:#?}");

        let mut spawned = cmd.spawn().context(context.clone())?;
        let finished = spawned.wait().context(context.clone())?;
        if !finished.success() {
            bail!("{context} failed.");
        }

        Ok(())
    }
}

mod business {
    use std::{
        collections::{HashMap, HashSet},
        io::Write,
    };

    use anyhow::{bail, Context, Result};
    use log::{debug, info, trace, warn};
    use tempfile::NamedTempFile;

    #[derive(Debug)]
    pub(crate) struct BuildInfo(HashMap<String, String>);

    // FIXME: is hardocing these in a type and functions sustainable, or is a config map appropriate?
    impl BuildInfo {
        // example var: 'PROP_project=holochain/holochain-infra
        pub(crate) fn from_env() -> Self {
            let env_vars = HashMap::<String, String>::from_iter(std::env::vars());

            let new_self = Self(env_vars);
            trace!("env vars: {new_self:#?}");

            new_self
        }
        fn get(&self, var: &str) -> Result<&String> {
            self.0
                .get(var)
                .context(format!("looking up {var} in {self:#?}"))
        }

        pub(crate) fn try_owners(&self) -> Result<HashSet<String>> {
            let value = self.get("PROP_owners")?;
            let vec: Vec<String> = serde_json::from_str(&value.replace("\'", "\""))
                .context(format!("parsing {value:?} as JSON"))?;

            Ok(HashSet::from_iter(vec))
        }
        pub(crate) fn try_org_repo(&self) -> Result<(&str, &str)> {
            let value = self.get("PROP_project")?;

            if let Some(split) = value.split_once("/") {
                Ok(split)
            } else {
                bail!("couldn't parse project {value}");
            }
        }

        pub(crate) fn try_attr(&self) -> Result<&String> {
            self.get("PROP_attr")
        }

        pub(crate) fn try_attr_name(&self) -> Result<&str> {
            let attr = self.get("PROP_attr")?;

            attr.split_once(".")
                .ok_or_else(|| anyhow::anyhow!("{attr} does not contain a '.'"))
                .map(|r| r.1)
        }
    }

    /// Verifies that the build current owners are trusted.
    // FIXME: make trusted owners configurable
    pub(crate) fn check_owners(owners: HashSet<String>) -> anyhow::Result<()> {
        const TRUSTED_OWNERS: [&str; 1] = ["steveej"];
        let trusted_owners = HashSet::<String>::from_iter(TRUSTED_OWNERS.map(ToString::to_string));
        let owner_is_trusted = owners.is_subset(&trusted_owners);
        if !owner_is_trusted {
            bail!("{owners:?} are *NOT* trusted!");
        }
        info!("owners {owners:?} are trusted! proceeding.");

        Ok(())
    }

    /// Evaluates the project org and accordingly returns a signing key.
    pub(crate) fn may_get_signing_key_and_copy_destination(
        build_info: &BuildInfo,
    ) -> anyhow::Result<Option<(NamedTempFile, String)>> {
        let (org, repo) = build_info.try_org_repo()?;

        let wrap_secret_in_tempfile = |s: &str| -> anyhow::Result<_> {
            let mut tempfile = NamedTempFile::new()?;
            tempfile.write_all(s.as_bytes())?;
            Ok(tempfile)
        };

        let attr_name = build_info.try_attr_name()?;

        // FIXME: remove this? it's used for testing purposes
        let override_holo_sign =
            { org == "holochain" && repo == "holochain-infra" && attr_name == "pre-commit-check" };
        debug!("override_holo_sign? {override_holo_sign:#?}");

        let maybe_data = if org.to_lowercase() == "holo-host" || override_holo_sign {
            // FIXME: create a constant or config value for this
            let secret = build_info.get("SECRET_cacheHoloHost2secret")?;

            let copy_destination = {
                // FIXME: create a config map for all the below

                // TODO: is the secret-key still needed when `nix sign` is performed separately? &secret-key=/var/lib/hydra/queue-runner/keys/${signingKeyName}/secret
                // TODO: will this accumulate a cache locally that needs maintenance?

                let s3_bucket = "cache.holo.host";
                let s3_endpoint = "s3.wasabisys.com";
                let s3_profile = "cache-holo-host-s3-wasabi";

                format!("s3://{s3_bucket}?")
                    + &[
                        vec![
                            format!("endpoint={s3_endpoint}"),
                            format!("profile={s3_profile}"),
                        ],
                        [
                            "log-compression=br",
                            "ls-compression=br",
                            "parallel-compression=1",
                            "write-nar-listing=1",
                        ]
                        .into_iter()
                        .map(ToString::to_string)
                        .collect(),
                    ]
                    .concat()
                    .join("&")
            };

            Some((wrap_secret_in_tempfile(secret)?, copy_destination))
        } else if org.to_lowercase() == "holochain" {
            info!("TODO: sign with holochain's key");
            None
        } else {
            warn!("unknown org: {org}");
            None
        };

        let data = if let Some(data) = maybe_data {
            data
        } else {
            return Ok(None);
        };

        let is_match_lossy = |re: &str, s: &str| {
            let is_match = pcre2::bytes::Regex::new(re)
                .map_err(|e| {
                    log::error!("error parsing {re} as regex: {e}");
                })
                .and_then(|re| {
                    re.is_match(s.as_bytes()).map_err(|e| {
                        log::error!("error parsing {re:?} as regex: {e}");
                    })
                })
                .unwrap_or(false);

            debug!("{re} matched {s}: {is_match}");

            is_match
        };

        // pass and exclude filter for well-known attrs
        // FIXME: create a config map for this
        const ATTR_PASS_FILTER_RE: &str = ".*pre-commit-check";
        // FIXME: create a config map for this
        const ATTR_EXCLUDE_FILTER_RE: &str = "tests-.*";
        let attr = build_info.try_attr()?;
        let pass = is_match_lossy(ATTR_PASS_FILTER_RE, attr)
            && !is_match_lossy(ATTR_EXCLUDE_FILTER_RE, attr);
        if !pass {
            warn!("excluding '{attr}'.");
            return Ok(None);
        }

        Ok(Some(data))
    }
}

#[cfg(test)]
mod tests {
    // TODO

    /*
    initial testing done manually using

    env \
        PROP_owners="['steveej']" \
        PROP_project="holochain/holochain-infra" \
        PROP_attr="aarch64-linux.pre-commit-check" \
        SECRET_cacheHoloHost2secret="testing:27QUePIhJDF8BK3l3R8qP78Id9LeRsrp/ScD84ulL7BVv0McPC8+p+9zgvtsNzvCubLzyQNzpjIshSqoC7XmEQ==" \
        nix run .\#postbuildstepper
     */
}
