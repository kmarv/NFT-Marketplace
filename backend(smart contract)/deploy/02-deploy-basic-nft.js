const { network } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")


module.exports= async({getNamedAccounts, deployments}) =>{
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const waitBlockConfirmations = developmentChains.includes(network.name)
        ? 1
        : VERIFICATION_BLOCK_CONFIRMATIONS

    const args = []
    const basicNFT = await deploy("BasicNft", {
        from:deployer,
        args:args,
        log:true,
        waitConfirmations: waitBlockConfirmations,
    })
    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify(basicNFT.address, args)
    }
    log("----------------------------------------------------")
}

module.exports.tags = ["all", "basicnft"]