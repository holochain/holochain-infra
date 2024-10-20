use anyhow::{bail, Context, Ok};
use log::{debug, info, trace, warn};
use std::{
    collections::{HashMap, HashSet},
    io::Write,
    path::PathBuf,
    process::Stdio,
};
use tempfile::{tempfile, NamedTempFile, TempPath};

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

    let env_vars = HashMap::<String, String>::from_iter(std::env::vars());
    debug!("env vars: {env_vars:#?}");

    check_owners(&env_vars)?;

    let (signing_key_file, s3_credentials_profile) =
        if let Some(skf) = may_get_signing_key_and_s3_credentials(&env_vars)? {
            skf
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

    let store_path = "TODO";

    // sign the store path
    {
        let mut cmd = std::process::Command::new("nix");
        cmd.args([
            "store",
            "sign",
            "--recursive",
            &format!("--key-file={signing_key_file_path}"),
            store_path,
        ])
        // let stdio go through so it's visible in the logs
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit());

        cmd.spawn().context(format!("running {cmd:#?}"))?;

        info!("successfully signed store path {store_path}");
    }

    // copy the store path
    {
        let mut cmd = std::process::Command::new("nix");
        cmd.args(["copy", "--to", copy_destination, store_path])
            // let stdio go through so it's visible in the logs
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit());

        cmd.spawn().context(format!("running {cmd:#?}"))?;

        debug!("TODO: push to s3");
    }

    Ok(())
}

/// Evaluates the project org and accordingly returns a signing key.
fn may_get_signing_key_and_s3_credentials(
    env_vars: &HashMap<String, String>,
) -> Result<Option<(NamedTempFile, String)>, anyhow::Error> {
    let (org, _) = {
        // example var: 'PROP_project=holochain/holochain-infra

        // FIXME: create a constant or config value for this
        let var = "PROP_project";
        let value = env_vars
            .get(var)
            .context(format!("looking up {var} in {env_vars:#?}"))?;

        if let Some(split) = value.split_once("/") {
            split
        } else {
            bail!("couldn't parse project {value}");
        }
    };

    let wrap_secret_in_tempfile = |s: &str| {
        let mut tempfile = NamedTempFile::new()?;
        tempfile.write_all(s.as_bytes())?;
        Ok(tempfile)
    };

    // FIXME: remove this? it's used for testing purposes
    let override_holo_sign = {
        // example var: 'PROP_project=holochain/holochain-infra

        // FIXME: create a constant or config value for this
        let var = "PROP_attr";

        let value = env_vars
            .get(var)
            .context(format!("looking up {var} in {env_vars:#?}"))?;

        value == "aarch64-darwin.pre-commit-check"
    };

    if org.to_lowercase() == "holo-host" || override_holo_sign {
        info!("TODO: sign with holo's key");

        // FIXME: create a constant or config value for this
        // TODO: use the secret key instead
        let var = "SECRET_cacheHoloHost2public";
        let value = env_vars
            .get(var)
            .context(format!("looking up {var} in {env_vars:#?}"))?;

        let copy_destination = {
            // FIXME: create a config map for these
            let s3_bucket = "cache.holo.host";
            let s3_endpoint = "s3.wasabisys.com";
            let s3_profile = "cache-holo-host-s3-wasabi";

            // TODO: is the secret-key still needed when `nix sign` is performed separately?
            // &secret-key=/var/lib/hydra/queue-runner/keys/${signingKeyName}/secret
            // TODO: will this accumulate a cache locally that needs maintenance?
            format!("s3://{s3_bucket}?endpoint=${s3_endpoint}&log-compression=br&ls-compression=br&parallel-compression=1&write-nar-listing=1&profile={s3_profile}")
        };

        Ok(Some((wrap_secret_in_tempfile(value)?, copy_destination)))
    } else if org.to_lowercase() == "holochain" {
        info!("TODO: sign with holochain's key");

        Ok(None)
    } else {
        warn!("unknown org: {org}");
        Ok(None)
    }
}

fn check_owners(env_vars: &HashMap<String, String>) -> Result<(), anyhow::Error> {
    let trusted_owners = HashSet::<String>::from_iter(["steveej"].map(ToString::to_string));
    let owners: HashSet<String> = {
        let var = "PROP_owners";

        let value = env_vars
            .get(var)
            .context(format!("looking up {var} in {env_vars:#?}"))?;

        let vec: Vec<String> = serde_json::from_str(&value.replace("\'", "\""))
            .context(format!("parsing {value:?} as JSON"))?;

        HashSet::from_iter(vec)
    };
    let owner_is_trusted = owners.is_subset(&trusted_owners);
    if !owner_is_trusted {
        bail!("{owners:#?} are *NOT* trusted!");
    }
    info!("{owners:#?} are trusted! proceeding.");

    Ok(())
}
