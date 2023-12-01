[![GitHub Actions](https://github.com/VenusProtocol/venus-protocol/actions/workflows/cd.yml/badge.svg)](https://github.com/VenusProtocol/venus-protocol/actions/workflows/cd.yml) [![GitHub Actions](https://github.com/VenusProtocol/venus-protocol/actions/workflows/ci.yml/badge.svg)](https://github.com/VenusProtocol/venus-protocol/actions/workflows/ci.yml)

# Venus Protocol

The Venus Protocol is a BNB Chain collection of smart contract for supplying or borrowing assets. Through the vToken contracts, accounts on the blockchain _supply_ capital (BNB or BEP-20 tokens) to receive vTokens or _borrow_ assets from the protocol (holding other assets as collateral). The protocol will also enable the minting of VAI, which is the first synthetic stablecoin on Venus that aims to be pegged to 1 USD. VAI is minted by the same collateral that is supplied to the protocol. The Venus vToken contracts track these balances and algorithmically set interest rates for borrowers and suppliers.

Before getting started with this repo, please read:

- [Venus Whitepaper](https://github.com/VenusProtocol/venus-protocol/tree/main/docs/VenusWhitepaper.pdf)

Interested in contributing? Please checkout our [contributing guidelines](./docs/CONTRIBUTING.md)

[Isolated pool](https://github.com/VenusProtocol/isolated-pools) is the updated version of the Venus protocol. The Venus "Core Pool" uses the codebase in this repository. On the other hand, Isolated pools use the codebase in the [isolated-pools](https://github.com/VenusProtocol/isolated-pools) repository.

# Contracts

We detail a few of the core contracts in the Venus protocol.

<dl>
  <dt>VToken, VBep20 and VBNB</dt>
  <dd>The Venus vTokens, which are self-contained borrowing and lending contracts. VToken contains the core logic and VBep20, VBUSD, and VBNB add public interfaces for BEP-20 tokens and bnb, respectively. Each VToken is assigned an interest rate and risk model (see InterestRateModel and Comptroller sections), and allows accounts to *mint* (supply capital), *redeem* (withdraw capital), *borrow* and *repay a borrow*. Each VToken is an BEP-20 compliant token where balances represent ownership of the market.</dd>
</dl>

<dl>
  <dt>Diamond Comptroller</dt>
  <dd>The risk model contract, which validates permissible user actions and disallows actions if they do not fit certain risk parameters. For instance, the Comptroller enforces that each borrowing user must maintain a sufficient collateral balance across all vTokens. The Comptroller is implemented as a Diamond proxy with several facets (MarketFacet, PolicyFacet, RewardFacet, SetterFacet) corresponding to the particular parts of the Comptroller functionality.</dd>
</dl>

<dl>
  <dt>XVS</dt>
  <dd>The Venus Governance Token (XVS). Holders of this token have the ability to govern the protocol via the governor contract.</dd>
</dl>

<dl>
  <dt>Governor Bravo</dt>
  <dd>The administrator of the Venus Timelock contracts. Holders of XVS token who have locked their tokens in XVSVault may create and vote on proposals which will be queued into the Venus Timelock and then have effects on other Venus contracts.</dd>
</dl>

<dl>
  <dt>InterestRateModel, JumpRateModel, WhitepaperInterestRateModel</dt>
  <dd>Contracts which define interest rate models. These models algorithmically determine interest rates based on the current utilization of a given market (that is, how much of the supplied assets are liquid versus borrowed).</dd>
</dl>

<dl>
  <dt>Careful Math</dt>
  <dd>Library for safe math operations.</dd>
</dl>

<dl>
  <dt>ErrorReporter</dt>
  <dd>Library for tracking error codes and failure conditions.</dd>
</dl>

<dl>
  <dt>Exponential</dt>
  <dd>Library for handling fixed-point decimal numbers.</dd>
</dl>

### Documentation

- Public documentation site: https://docs.venus.io, including autogernated documentation, guides, addresses of the deployment contracts and more content.
- Documentation autogenerated using [solidity-docgen](https://github.com/OpenZeppelin/solidity-docgen).
- To generate the documentation from the natspec comments embedded in the contracts, use `yarn docgen`

## Installation

To run venus, pull the repository from GitHub and install its dependencies. You will need [yarn](https://yarnpkg.com/lang/en/docs/install/) or [npm](https://docs.npmjs.com/cli/install) installed.

    git clone https://github.com/VenusProtocol/venus-protocol
    cd venus-protocol
    yarn install --lock-file # or `npm install`

## Testing

Contract tests are defined under the [tests directory](https://github.com/VenusProtocol/venus-protocol/tree/main/tests). To run the tests run:

```

    yarn test

```

- To run fork tests add `FORK=true`, `FORKED_NETWORK` and one `ARCHIVE_NODE` var in the `.env` file.

## Code Coverage

To run code coverage, run:

```

npx hardhat coverage

```

## Deployment

```

npx hardhat deploy

```

- This command will execute all the deployment scripts in `./deploy` directory - It will skip only deployment scripts which implement a `skip` condition - Here is example of a skip condition: - Skipping deployment script on `bsctestnet` network `func.skip = async (hre: HardhatRuntimeEnvironment) => hre.network.name !== "bsctestnet";`
- The default network will be `hardhat`
- Deployment to another network: - Make sure the desired network is configured in `hardhat.config.ts` - Add `MNEMONIC` variable in `.env` file - Execute deploy command by adding `--network <network_name>` in the deploy command above - E.g. `npx hardhat deploy --network bsctestnet`
- Execution of single or custom set of scripts is possible, if:
  - In the deployment scripts you have added `tags` for example: - `func.tags = ["MockTokens"];`
  - Once this is done, adding `--tags "<tag_name>,<tag_name>..."` to the deployment command will execute only the scripts containing the tags.

### Deployed Contracts

Contract addresses deployed before `hardhat-deploy` was adopted are available in the `networking` directory in JSON files by network name.

Contract addresses and abis deployed with hardhat deploy are exported in the `deployments` directory. To create a summary export of all contracts deployed to a network run.

```
$ yarn hardhat --network <network-name> --export ./deployments/<network-name>.json
```

### Source Code Verification

In order to verify the source code of already deployed contracts, run:
`npx hardhat etherscan-verify --network <network_name>`

Make sure you have added `ETHERSCAN_API_KEY` in `.env` file.

## Linting

To lint the code, run:

```

yarn lint

```

To format the code, run:

```

yarn prettier

```

## Hardhat Commands

```

npx hardhat accounts

npx hardhat compile

npx hardhat clean

npx hardhat test

npx hardhat node

npx hardhat help

REPORT_GAS=true npx hardhat test

npx hardhat coverage

TS_NODE_FILES=true npx ts-node scripts/deploy.ts

npx eslint '\*_/_.{js,ts}'

npx eslint '\*_/_.{js,ts}' --fix

npx prettier '\*_/_.{json,sol,md}' --check

npx prettier '\*_/_.{json,sol,md}' --write

npx solhint 'contracts/\*_/_.sol'

npx solhint 'contracts/\*_/_.sol' --fix

MNEMONIC="<>" BSC_API_KEY="<>" npx hardhat run ./script/hardhat/deploy.ts --network testnet

```

## Discussion

For any concerns with the protocol, open an issue or visit us on [Telegram](https://t.me/venusprotocol) to discuss.

For security concerns, please contact the administrators of our telegram chat.

© Copyright 2023, Venus Protocol
