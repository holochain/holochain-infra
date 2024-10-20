/// This designed to be executed from within buildbot-nix in a postBuildStep.
/// It currently hardcodes assumptions that are specific to Holo/Holochain's build environment.
///
use anyhow::Ok;
use business::SigningAndCopyInfo;
use log::{info, warn};
use std::collections::HashMap;

fn main() -> anyhow::Result<()> {
    env_logger::builder()
        .filter_level(log::LevelFilter::Debug)
        .init();

    let build_info = business::BuildInfo::from_env();

    let _ = business::check_owners(build_info.try_owners()?);

    let SigningAndCopyInfo {
        signing_key_file,
        copy_envs,
        copy_destination,
    } = if let Some(info) = business::may_get_signing_key_and_copy_info(&build_info)? {
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

    let store_path = build_info.try_out_path()?;

    // sign the store path
    util::nix_cmd_helper(
        [
            "store",
            "sign",
            "--verbose",
            "--recursive",
            "--key-file",
            signing_key_file_path,
            store_path,
        ],
        HashMap::<&&str, &str>::new(),
    )?;
    info!("successfully signed store path {store_path}");

    // copy the store path
    util::nix_cmd_helper(
        ["copy", "--verbose", "--to", &copy_destination, store_path],
        copy_envs.iter().map(|(k, v)| (k, v.path().as_os_str())),
    )?;
    info!("successfully pushed store path {store_path}");

    Ok(())
}

mod util {
    use std::{ffi::OsStr, process::Stdio};

    use anyhow::{bail, Context};

    pub(crate) fn nix_cmd_helper<I, J, K, V, L>(args: I, envs: J) -> anyhow::Result<()>
    where
        I: IntoIterator<Item = K>,
        J: IntoIterator<Item = (V, L)>,
        K: AsRef<OsStr>,
        V: AsRef<OsStr>,
        L: AsRef<OsStr>,
    {
        let mut cmd = std::process::Command::new("nix");
        cmd.args(args)
            .envs(envs)
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
        ffi::OsString,
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

        pub(crate) fn try_out_path(&self) -> Result<&String> {
            self.get("PROP_out_path")
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

    /// Contains information to sign and upload the build results
    pub(crate) struct SigningAndCopyInfo {
        pub(crate) signing_key_file: NamedTempFile,
        pub(crate) copy_envs: HashMap<OsString, NamedTempFile>,
        pub(crate) copy_destination: String,
    }

    /// Evaluates the project org and accordingly returns a signing key.
    pub(crate) fn may_get_signing_key_and_copy_info(
        build_info: &BuildInfo,
    ) -> anyhow::Result<Option<SigningAndCopyInfo>> {
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
            let signing_secret = build_info.get("SECRET_cacheHoloHost2secret")?;
            let copy_envs = HashMap::from_iter([(
                // FIXME: create a constant or config value for this
                OsString::from("AWS_SHARED_CREDENTIALS_FILE"),
                wrap_secret_in_tempfile(build_info.get("SECRET_awsSharedCredentialsFile")?)?,
            )]);

            let copy_destination = {
                // FIXME: create a config map for all the below

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

            Some(SigningAndCopyInfo {
                signing_key_file: wrap_secret_in_tempfile(signing_secret)?,
                copy_envs,
                copy_destination,
            })
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
        const ATTR_PASS_FILTER_RE: &str = "aarch64-.*\\.pre-commit-check";
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
    /*
        TODO: initial testing done manually using `nix run .#postbuildstepper-test``
    */
}
