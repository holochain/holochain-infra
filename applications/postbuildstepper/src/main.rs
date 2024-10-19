use anyhow::{bail, Context};
use log::{debug, info, trace};
use std::collections::{HashMap, HashSet};

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

    debug!("TODO: if org is holo-host sign store path recursively");
    debug!("TODO: if org is holo-host push to s3");

    Ok(())
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
