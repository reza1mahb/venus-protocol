pragma solidity 0.8.13;
import "../../Tokens/VTokens/VToken.sol";
import "./appStorage.sol";
import "./LibAccessCheck.sol";
import "../../Utils/ErrorReporter.sol";
import "./LibExponentialNoError.sol";

import "../../Utils/ExponentialNoError.sol";

library LibHelper {
    /// @notice The initial Venus index for a market
    uint224 public constant venusInitialIndex = 1e36;
    // closeFactorMantissa must be strictly greater than this value
    uint internal constant closeFactorMinMantissa = 0.05e18; // 0.05
    // closeFactorMantissa must not exceed this value
    uint internal constant closeFactorMaxMantissa = 0.9e18; // 0.9
    // No collateralFactorMantissa may exceed this value
    uint internal constant collateralFactorMaxMantissa = 0.9e18; // 0.9

    /**
     * @notice Determine what the account liquidity would be if the given amounts were redeemed/borrowed
     * @param vTokenModify The market to hypothetically redeem/borrow in
     * @param account The account to determine liquidity for
     * @param redeemTokens The number of tokens to hypothetically redeem
     * @param borrowAmount The amount of underlying to hypothetically borrow
     * @dev Note that we calculate the exchangeRateStored for each collateral vToken using stored data,
     *  without calculating accumulated interest.
     * @return (possible error code,
                hypothetical account liquidity in excess of collateral requirements,
     *          hypothetical account shortfall below collateral requirements)
     */
    function getHypotheticalAccountLiquidityInternal(
        address account,
        VToken vTokenModify,
        uint redeemTokens,
        uint borrowAmount
    ) internal view returns (ComptrollerErrorReporter.Error, uint, uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        (uint err, uint liquidity, uint shortfall) = s.comptrollerLens.getHypotheticalAccountLiquidity(
            address(this),
            account,
            vTokenModify,
            redeemTokens,
            borrowAmount
        );
        return (ComptrollerErrorReporter.Error(err), liquidity, shortfall);
    }

    /**
     * @notice Accrue XVS to the market by updating the supply index
     * @param vToken The market whose supply index to update
     */
    function updateVenusSupplyIndex(address vToken) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        VenusMarketState storage supplyState = s.venusSupplyState[vToken];
        uint supplySpeed = s.venusSupplySpeeds[vToken];
        uint32 blockNumber = LibExponentialNoError.safe32(
            LibAccessCheck.getBlockNumber(),
            "block number exceeds 32 bits"
        );
        uint deltaBlocks = LibExponentialNoError.sub_(uint(blockNumber), uint(supplyState.block));
        if (deltaBlocks > 0 && supplySpeed > 0) {
            uint supplyTokens = VToken(vToken).totalSupply();
            uint venusAccrued = LibExponentialNoError.mul_(deltaBlocks, supplySpeed);
            LibExponentialNoError.Double memory ratio = supplyTokens > 0
                ? LibExponentialNoError.fraction(venusAccrued, supplyTokens)
                : LibExponentialNoError.Double({ mantissa: 0 });
            supplyState.index = LibExponentialNoError.safe224(
                LibExponentialNoError
                    .add_(LibExponentialNoError.Double({ mantissa: supplyState.index }), ratio)
                    .mantissa,
                "new index exceeds 224 bits"
            );
            supplyState.block = blockNumber;
        } else if (deltaBlocks > 0) {
            supplyState.block = blockNumber;
        }
    }

    /**
     * @notice Accrue XVS to the market by updating the borrow index
     * @param vToken The market whose borrow index to update
     */
    function updateVenusBorrowIndex(address vToken, ExponentialNoError.Exp memory marketBorrowIndex) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        VenusMarketState storage borrowState = s.venusBorrowState[vToken];
        uint borrowSpeed = s.venusBorrowSpeeds[vToken];
        uint32 blockNumber = LibExponentialNoError.safe32(
            LibAccessCheck.getBlockNumber(),
            "block number exceeds 32 bits"
        );
        uint deltaBlocks = LibExponentialNoError.sub_(uint(blockNumber), uint(borrowState.block));
        if (deltaBlocks > 0 && borrowSpeed > 0) {
            uint borrowAmount = LibExponentialNoError.div_(VToken(vToken).totalBorrows(), marketBorrowIndex);
            uint venusAccrued = LibExponentialNoError.mul_(deltaBlocks, borrowSpeed);
            LibExponentialNoError.Double memory ratio = borrowAmount > 0
                ? LibExponentialNoError.fraction(venusAccrued, borrowAmount)
                : LibExponentialNoError.Double({ mantissa: 0 });
            borrowState.index = LibExponentialNoError.safe224(
                LibExponentialNoError
                    .add_(LibExponentialNoError.Double({ mantissa: borrowState.index }), ratio)
                    .mantissa,
                "new index exceeds 224 bits"
            );
            borrowState.block = blockNumber;
        } else if (deltaBlocks > 0) {
            borrowState.block = blockNumber;
        }
    }

    /**
     * @notice Calculate XVS accrued by a supplier and possibly transfer it to them
     * @param vToken The market in which the supplier is interacting
     * @param supplier The address of the supplier to distribute XVS to
     */
    function distributeSupplierVenus(address vToken, address supplier) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (address(s.vaiVaultAddress) != address(0)) {
            // releaseToVault();
        }
        uint supplyIndex = s.venusSupplyState[vToken].index;
        uint supplierIndex = s.venusSupplierIndex[vToken][supplier];
        // Update supplier's index to the current index since we are distributing accrued XVS
        s.venusSupplierIndex[vToken][supplier] = supplyIndex;
        if (supplierIndex == 0 && supplyIndex >= venusInitialIndex) {
            // Covers the case where users supplied tokens before the market's supply state index was set.
            // Rewards the user with XVS accrued from the start of when supplier rewards were first
            // set for the market.
            supplierIndex = venusInitialIndex;
        }
        // Calculate change in the cumulative sum of the XVS per vToken accrued
        LibExponentialNoError.Double memory deltaIndex = LibExponentialNoError.Double({
            mantissa: LibExponentialNoError.sub_(supplyIndex, supplierIndex)
        });
        // Multiply of supplierTokens and supplierDelta
        uint supplierDelta = LibExponentialNoError.mul_(VToken(vToken).balanceOf(supplier), deltaIndex);
        // Addition of supplierAccrued and supplierDelta
        s.venusAccrued[supplier] = LibExponentialNoError.add_(s.venusAccrued[supplier], supplierDelta);
        // emit DistributedSupplierVenus(VToken(vToken), supplier, supplierDelta, supplyIndex);
    }

    /**
     * @notice Calculate XVS accrued by a borrower and possibly transfer it to them
     * @dev Borrowers will not begin to accrue until after the first interaction with the protocol.
     * @param vToken The market in which the borrower is interacting
     * @param borrower The address of the borrower to distribute XVS to
     */
    function distributeBorrowerVenus(
        address vToken,
        address borrower,
        ExponentialNoError.Exp memory marketBorrowIndex
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (address(s.vaiVaultAddress) != address(0)) {
            // releaseToVault();
        }
        uint borrowIndex = s.venusBorrowState[vToken].index;
        uint borrowerIndex = s.venusBorrowerIndex[vToken][borrower];
        // Update borrowers's index to the current index since we are distributing accrued XVS
        s.venusBorrowerIndex[vToken][borrower] = borrowIndex;
        if (borrowerIndex == 0 && borrowIndex >= venusInitialIndex) {
            // Covers the case where users borrowed tokens before the market's borrow state index was set.
            // Rewards the user with XVS accrued from the start of when borrower rewards were first
            // set for the market.
            borrowerIndex = venusInitialIndex;
        }
        // Calculate change in the cumulative sum of the XVS per borrowed unit accrued
        LibExponentialNoError.Double memory deltaIndex = LibExponentialNoError.Double({
            mantissa: LibExponentialNoError.sub_(borrowIndex, borrowerIndex)
        });
        uint borrowerDelta = LibExponentialNoError.mul_(
            LibExponentialNoError.div_(VToken(vToken).borrowBalanceStored(borrower), marketBorrowIndex),
            deltaIndex
        );
        s.venusAccrued[borrower] = LibExponentialNoError.add_(s.venusAccrued[borrower], borrowerDelta);
        // emit DistributedBorrowerVenus(VToken(vToken), borrower, borrowerDelta, borrowIndex);
    }

    /**
     * @notice Add the market to the borrower's "assets in" for liquidity calculations
     * @param vToken The market to enter
     * @param borrower The address of the account to modify
     * @return Success indicator for whether the market was entered
     */
    function addToMarketInternal(VToken vToken, address borrower) internal returns (ComptrollerErrorReporter.Error) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        LibAccessCheck.checkActionPauseState(address(vToken), LibAccessCheck.Action.ENTER_MARKET);
        Market storage marketToJoin = s.markets[address(vToken)];
        LibAccessCheck.ensureListed(marketToJoin);
        if (marketToJoin.accountMembership[borrower]) {
            // already joined
            return ComptrollerErrorReporter.Error.NO_ERROR;
        }
        // survived the gauntlet, add to list
        // NOTE: we store these somewhat redundantly as a significant optimization
        //  this avoids having to iterate through the list for the most common use cases
        //  that is, only when we need to perform liquidity checks
        //  and not whenever we want to check if an account is in a particular market
        marketToJoin.accountMembership[borrower] = true;
        s.accountAssets[borrower].push(vToken);
        // emit MarketEntered(vToken, borrower);
        return ComptrollerErrorReporter.Error.NO_ERROR;
    }

    function redeemAllowedInternal(address vToken, address redeemer, uint redeemTokens) internal view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        LibAccessCheck.ensureListed(s.markets[vToken]);
        /* If the redeemer is not 'in' the market, then we can bypass the liquidity check */
        if (!s.markets[vToken].accountMembership[redeemer]) {
            return uint(ComptrollerErrorReporter.Error.NO_ERROR);
        }
        /* Otherwise, perform a hypothetical liquidity check to guard against shortfall */
        (ComptrollerErrorReporter.Error err, , uint shortfall) = getHypotheticalAccountLiquidityInternal(
            redeemer,
            VToken(vToken),
            redeemTokens,
            0
        );
        if (err != ComptrollerErrorReporter.Error.NO_ERROR) {
            return uint(err);
        }
        if (shortfall != 0) {
            return uint(ComptrollerErrorReporter.Error.INSUFFICIENT_LIQUIDITY);
        }
        return uint(ComptrollerErrorReporter.Error.NO_ERROR);
    }
}
