pragma solidity 0.8.13;

import { PrimeStorageV1 } from "../PrimeStorage.sol";

/**
 * @title IPrime
 * @author Venus
 * @notice Interface for Prime Token
 */
interface IPrime {
    /**
     * @notice Returns boosted pending interest accrued for a user for all markets
     * @param user the account for which to get the accrued interests
     * @return pendingInterests the number of underlying tokens accrued by the user for all markets
     */
    function getPendingInterests(
        address user
    ) external returns (PrimeStorageV1.PendingInterest[] memory pendingInterests);

    /**
     * @notice Update total score of multiple users and market
     * @param users accounts for which we need to update score
     */
    function updateScores(address[] memory users) external;

    /**
     * @notice Update value of alpha
     * @param _alphaNumerator numerator of alpha. If alpha is 0.5 then numerator is 1
     * @param _alphaDenominator denominator of alpha. If alpha is 0.5 then denominator is 2
     */
    function updateAlpha(uint128 _alphaNumerator, uint128 _alphaDenominator) external;

    /**
     * @notice Update multipliers for a market
     * @param market address of the market vToken
     * @param supplyMultiplier new supply multiplier for the market, scaled by 1e18
     * @param borrowMultiplier new borrow multiplier for the market, scaled by 1e18
     */
    function updateMultipliers(address market, uint256 supplyMultiplier, uint256 borrowMultiplier) external;

    /**
     * @notice Add a market to prime program
     * @param market address of the market vToken
     * @param supplyMultiplier the multiplier for supply cap. It should be converted to 1e18
     * @param borrowMultiplier the multiplier for borrow cap. It should be converted to 1e18
     */
    function addMarket(address market, uint256 supplyMultiplier, uint256 borrowMultiplier) external;

    /**
     * @notice Set limits for total tokens that can be minted
     * @param _irrevocableLimit total number of irrevocable tokens that can be minted
     * @param _revocableLimit total number of revocable tokens that can be minted
     */
    function setLimit(uint256 _irrevocableLimit, uint256 _revocableLimit) external;

    /**
     * @notice Directly issue prime tokens to users
     * @param isIrrevocable are the tokens being issued
     * @param users list of address to issue tokens to
     */
    function issue(bool isIrrevocable, address[] calldata users) external;

    /**
     * @notice Executed by XVSVault whenever user's XVSVault balance changes
     * @param user the account address whose balance was updated
     */
    function xvsUpdated(address user) external;

    /**
     * @notice accrues interes and updates score for an user for a specific market
     * @param user the account address for which to accrue interest and update score
     * @param market the market for which to accrue interest and update score
     */
    function accrueInterestAndUpdateScore(address user, address market) external;

    /**
     * @notice For claiming prime token when staking period is completed
     */
    function claim() external;

    /**
     * @notice For burning any prime token
     * @param user the account address for which the prime token will be burned
     */
    function burn(address user) external;

    /**
     * @notice To pause or unpause claiming of interest
     */
    function togglePause() external;

    /**
     * @notice For user to claim boosted yield
     * @param vToken the market for which claim the accrued interest
     * @return amount the amount of tokens transferred to the user
     */
    function claimInterest(address vToken) external returns (uint256);

    /**
     * @notice For user to claim boosted yield
     * @param vToken the market for which claim the accrued interest
     * @param user the user for which to claim the accrued interest
     * @return amount the amount of tokens transferred to the user
     */
    function claimInterest(address vToken, address user) external returns (uint256);

    /**
     * @notice Distributes income from market since last distribution
     * @param vToken the market for which to distribute the income
     */
    function accrueInterest(address vToken) external;

    /**
     * @notice Returns boosted interest accrued for a user
     * @param vToken the market for which to fetch the accrued interest
     * @param user the account for which to get the accrued interest
     * @return interestAccrued the number of underlying tokens accrued by the user since the last accrual
     */
    function getInterestAccrued(address vToken, address user) external returns (uint256);

    /**
     * @notice Retrieves an array of all available markets
     * @return an array of addresses representing all available markets
     */
    function getAllMarkets() external view returns (address[] memory);

    /**
     * @notice fetch the numbers of seconds remaining for staking period to complete
     * @param user the account address for which we are checking the remaining time
     * @return timeRemaining the number of seconds the user needs to wait to claim prime token
     */
    function claimTimeRemaining(address user) external view returns (uint256);

    /**
     * @notice Returns supply and borrow APR for user for a given market
     * @param market the market for which to fetch the APR
     * @param user the account for which to get the APR
     * @return supplyAPR supply APR of the user in BPS
     * @return borrowAPR borrow APR of the user in BPS
     */
    function calculateAPR(address market, address user) external view returns (uint256 supplyAPR, uint256 borrowAPR);

    /**
     * @notice Returns supply and borrow APR for estimated supply, borrow and XVS staked
     * @param market the market for which to fetch the APR
     * @param user the account for which to get the APR
     * @param borrow hypothetical borrow amount
     * @param supply hypothetical supply amount
     * @param xvsStaked hypothetical staked XVS amount
     * @return supplyAPR supply APR of the user in BPS
     * @return borrowAPR borrow APR of the user in BPS
     */
    function estimateAPR(
        address market,
        address user,
        uint256 borrow,
        uint256 supply,
        uint256 xvsStaked
    ) external view returns (uint256 supplyAPR, uint256 borrowAPR);
}
