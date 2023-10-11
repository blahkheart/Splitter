import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
/**
 * Deploys a contract named "Splitter" using the deployer account and
 * constructor arguments set to the deployer address
 *
 * @param hre HardhatRuntimeEnvironment object.
 */
const deploySplitter: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  /*
    On localhost, the deployer account is the one that comes with Hardhat, which is already funded.

    When deploying to live networks (e.g `yarn deploy --network goerli`), the deployer account
    should have sufficient balance to pay for the gas fees for contract creation.

    You can generate a random account with `yarn generate` which will fill DEPLOYER_PRIVATE_KEY
    with a random private key in the .env file (then used on hardhat.config.ts)
    You can run the `yarn account` command to check your balance in every network.
  */
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  await deploy("Splitter", {
    from: deployer,
    // Contract constructor arguments
    // args: [deployer],
    log: true,
    // autoMine: can be passed to the deploy function to make the deployment process faster on local networks by
    // automatically mining the contract deployment transaction. There is no effect on live networks.
    autoMine: true,
  });

  // Get the deployed contract
  const yourContract = await hre.ethers.getContract("Splitter", deployer);
  const tx = await yourContract.transferOwnership("0xE11Cd5244DE68D90755a1d142Ab446A4D17cDC10");
  console.log("txn hash:", tx.hash);
};

export default deploySplitter;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags Splitter
deploySplitter.tags = ["Splitter"];
