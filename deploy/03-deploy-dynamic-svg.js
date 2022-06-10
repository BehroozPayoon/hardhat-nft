const { network } = require("hardhat")
const { developmentChains, networkConfig } = require("../helper-hardhat-config")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId
    const fs = require("fs")

    let ethUsdPriceFeedAddress
    if (developmentChains.includes(network.name)) {
        const ethUsdPriceAggregator = await deployments.get("MockV3Aggregator")
        ethUsdPriceFeedAddress = ethUsdPriceAggregator.address
    } else {
        ethUsdPriceFeedAddress = networkConfig[chainId].ethUsdPriceFeed
    }

    const lowSVG = await fs.readFileSync("./images/dynamicNft/frown.svg", { encoding: "utf8" })
    const highSVG = await fs.readFileSync("./images/dynamicNft/happy.svg", { encoding: "utf8" })

    log("----------------------------------------------------")
    const arguments = [ethUsdPriceFeedAddress, lowSVG, highSVG]
    const dynamicSvgNft = await deploy("DynamicSvgNft", {
        from: deployer,
        args: arguments,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify(dynamicSvgNft.address, arguments)
    }
}

module.exports.tags = ["all", "dynamicsvg", "main"]
