// SPDX-License-Identifier: AGPL-3.0-or-later
//
// DssVest - Token vesting contract
// MaseerVest - Token vesting contract with safeTransfer functionality
//
// Copyright (C) 2021 Dai Foundation
// Copyright (C) 2025 Maseer LTD
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.13;

interface Gem {
    function transferFrom(address src, address dst, uint wad) external returns (bool);
    function transfer(address dst, uint wad) external returns (bool);
}

abstract contract DssVest {
    // --- Data ---
    mapping (address => uint256) public wards;

    struct Award {
        address usr;   // Vesting recipient
        uint48  bgn;   // Start of vesting period  [timestamp]
        uint48  clf;   // The cliff date           [timestamp]
        uint48  fin;   // End of vesting period    [timestamp]
        address mgr;   // A manager address that can yank
        uint8   res;   // Restricted
        uint128 tot;   // Total reward amount
        uint128 rxd;   // Amount of vest claimed
    }
    mapping (uint256 => Award) public awards;

    uint256 public cap; // Maximum per-second issuance token rate

    uint256 public ids; // Total vestings

    uint256 internal locked;

    uint256 public constant  TWENTY_YEARS = 20 * 365 days;

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);

    event File(bytes32 indexed what, uint256 data);

    event Init(uint256 indexed id, address indexed usr);
    event Vest(uint256 indexed id, uint256 amt);
    event Restrict(uint256 indexed id);
    event Unrestrict(uint256 indexed id);
    event Yank(uint256 indexed id, uint256 end);
    event Move(uint256 indexed id, address indexed dst);

    // Getters to access only to the value desired
    function usr(uint256 _id) external view returns (address) {
        return awards[_id].usr;
    }

    function bgn(uint256 _id) external view returns (uint256) {
        return awards[_id].bgn;
    }

    function clf(uint256 _id) external view returns (uint256) {
        return awards[_id].clf;
    }

    function fin(uint256 _id) external view returns (uint256) {
        return awards[_id].fin;
    }

    function mgr(uint256 _id) external view returns (address) {
        return awards[_id].mgr;
    }

    function res(uint256 _id) external view returns (uint256) {
        return awards[_id].res;
    }

    function tot(uint256 _id) external view returns (uint256) {
        return awards[_id].tot;
    }

    function rxd(uint256 _id) external view returns (uint256) {
        return awards[_id].rxd;
    }

    /**
        @dev Base vesting logic contract constructor
    */
    constructor() {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    // --- Mutex ---
    modifier lock {
        require(locked == 0, "DssVest/system-locked");
        locked = 1;
        _;
        locked = 0;
    }

    // --- Auth ---
    modifier auth {
        require(wards[msg.sender] == 1, "DssVest/not-authorized");
        _;
    }

    function rely(address _usr) external auth {
        wards[_usr] = 1;
        emit Rely(_usr);
    }
    function deny(address _usr) external auth {
        wards[_usr] = 0;
        emit Deny(_usr);
    }

    /**
        @dev (Required) Set the per-second token issuance rate.
        @param what  The tag of the value to change (ex. bytes32("cap"))
        @param data  The value to update (ex. cap of 1000 tokens/yr == 1000*WAD/365 days)
    */
    function file(bytes32 what, uint256 data) external lock auth {
        if      (what == "cap")         cap = data;     // The maximum amount of tokens that can be streamed per-second per vest
        else revert("DssVest/file-unrecognized-param");
        emit File(what, data);
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x > y ? y : x;
    }
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "DssVest/add-overflow");
    }
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "DssVest/sub-underflow");
    }
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "DssVest/mul-overflow");
    }
    function toUint48(uint256 x) internal pure returns (uint48 z) {
        require((z = uint48(x)) == x, "DssVest/uint48-overflow");
    }
    function toUint128(uint256 x) internal pure returns (uint128 z) {
        require((z = uint128(x)) == x, "DssVest/uint128-overflow");
    }

    /**
        @dev Govanance adds a vesting contract
        @param _usr The recipient of the reward
        @param _tot The total amount of the vest
        @param _bgn The starting timestamp of the vest
        @param _tau The duration of the vest (in seconds)
        @param _eta The cliff duration in seconds (i.e. 1 years)
        @param _mgr An optional manager for the contract. Can yank if vesting ends prematurely.
        @return id  The id of the vesting contract
    */
    function create(address _usr, uint256 _tot, uint256 _bgn, uint256 _tau, uint256 _eta, address _mgr) external lock auth returns (uint256 id) {
        require(_usr != address(0),                        "DssVest/invalid-user");
        require(_tot > 0,                                  "DssVest/no-vest-total-amount");
        require(_bgn < add(block.timestamp, TWENTY_YEARS), "DssVest/bgn-too-far");
        require(_bgn > sub(block.timestamp, TWENTY_YEARS), "DssVest/bgn-too-long-ago");
        require(_tau > 0,                                  "DssVest/tau-zero");
        require(_tot / _tau <= cap,                        "DssVest/rate-too-high");
        require(_tau <= TWENTY_YEARS,                      "DssVest/tau-too-long");
        require(_eta <= _tau,                              "DssVest/eta-too-long");
        require(ids < type(uint256).max,                   "DssVest/ids-overflow");

        id = ++ids;
        awards[id] = Award({
            usr: _usr,
            bgn: toUint48(_bgn),
            clf: toUint48(add(_bgn, _eta)),
            fin: toUint48(add(_bgn, _tau)),
            tot: toUint128(_tot),
            rxd: 0,
            mgr: _mgr,
            res: 0
        });
        emit Init(id, _usr);
    }

    /**
        @dev Anyone (or only owner of a vesting contract if restricted) calls this to claim all available rewards
        @param _id     The id of the vesting contract
    */
    function vest(uint256 _id) external {
        _vest(_id, type(uint256).max);
    }

    /**
        @dev Anyone (or only owner of a vesting contract if restricted) calls this to claim rewards
        @param _id     The id of the vesting contract
        @param _maxAmt The maximum amount to vest
    */
    function vest(uint256 _id, uint256 _maxAmt) external {
        _vest(_id, _maxAmt);
    }

    /**
        @dev Anyone (or only owner of a vesting contract if restricted) calls this to claim rewards
        @param _id     The id of the vesting contract
        @param _maxAmt The maximum amount to vest
    */
    function _vest(uint256 _id, uint256 _maxAmt) internal lock {
        Award memory _award = awards[_id];
        require(_award.usr != address(0), "DssVest/invalid-award");
        require(_award.res == 0 || _award.usr == msg.sender, "DssVest/only-user-can-claim");
        uint256 amt = unpaid(block.timestamp, _award.bgn, _award.clf, _award.fin, _award.tot, _award.rxd);
        amt = min(amt, _maxAmt);
        awards[_id].rxd = toUint128(add(_award.rxd, amt));
        pay(_award.usr, amt);
        emit Vest(_id, amt);
    }

    /**
        @dev amount of tokens accrued, not accounting for tokens paid
        @param _id  The id of the vesting contract
        @return amt The accrued amount
    */
    function accrued(uint256 _id) external view returns (uint256 amt) {
        Award memory _award = awards[_id];
        require(_award.usr != address(0), "DssVest/invalid-award");
        amt = accrued(block.timestamp, _award.bgn, _award.fin, _award.tot);
    }

    /**
        @dev amount of tokens accrued, not accounting for tokens paid
        @param _time The timestamp to perform the calculation
        @param _bgn  The start time of the contract
        @param _fin  The end time of the contract
        @param _tot  The total amount of the contract
        @return amt  The accrued amount
    */
    function accrued(uint256 _time, uint48 _bgn, uint48 _fin, uint128 _tot) internal pure returns (uint256 amt) {
        if (_time < _bgn) {
            amt = 0;
        } else if (_time >= _fin) {
            amt = _tot;
        } else {
            amt = mul(_tot, sub(_time, _bgn)) / sub(_fin, _bgn); // 0 <= amt < _award.tot
        }
    }

    /**
        @dev return the amount of vested, claimable GEM for a given ID
        @param _id  The id of the vesting contract
        @return amt The claimable amount
    */
    function unpaid(uint256 _id) external view returns (uint256 amt) {
        Award memory _award = awards[_id];
        require(_award.usr != address(0), "DssVest/invalid-award");
        amt = unpaid(block.timestamp, _award.bgn, _award.clf, _award.fin, _award.tot, _award.rxd);
    }

    /**
        @dev amount of tokens accrued, not accounting for tokens paid
        @param _time The timestamp to perform the calculation
        @param _bgn  The start time of the contract
        @param _clf  The timestamp of the cliff
        @param _fin  The end time of the contract
        @param _tot  The total amount of the contract
        @param _rxd  The number of gems received
        @return amt  The claimable amount
    */
    function unpaid(uint256 _time, uint48 _bgn, uint48 _clf, uint48 _fin, uint128 _tot, uint128 _rxd) internal pure returns (uint256 amt) {
        amt = _time < _clf ? 0 : sub(accrued(_time, _bgn, _fin, _tot), _rxd);
    }

    /**
        @dev Allows governance or the owner to restrict vesting to the owner only
        @param _id The id of the vesting contract
    */
    function restrict(uint256 _id) external lock {
        address usr_ = awards[_id].usr;
        require(usr_ != address(0), "DssVest/invalid-award");
        require(wards[msg.sender] == 1 || usr_ == msg.sender, "DssVest/not-authorized");
        awards[_id].res = 1;
        emit Restrict(_id);
    }

    /**
        @dev Allows governance or the owner to enable permissionless vesting
        @param _id The id of the vesting contract
    */
    function unrestrict(uint256 _id) external lock {
        address usr_ = awards[_id].usr;
        require(usr_ != address(0), "DssVest/invalid-award");
        require(wards[msg.sender] == 1 || usr_ == msg.sender, "DssVest/not-authorized");
        awards[_id].res = 0;
        emit Unrestrict(_id);
    }

    /**
        @dev Allows governance or the manager to remove a vesting contract immediately
        @param _id The id of the vesting contract
    */
    function yank(uint256 _id) external {
        _yank(_id, block.timestamp);
    }

    /**
        @dev Allows governance or the manager to remove a vesting contract at a future time
        @param _id  The id of the vesting contract
        @param _end A scheduled time to end the vest
    */
    function yank(uint256 _id, uint256 _end) external {
        _yank(_id, _end);
    }

    /**
        @dev Allows governance or the manager to end pre-maturely a vesting contract
        @param _id  The id of the vesting contract
        @param _end A scheduled time to end the vest
    */
    function _yank(uint256 _id, uint256 _end) internal lock {
        require(wards[msg.sender] == 1 || awards[_id].mgr == msg.sender, "DssVest/not-authorized");
        Award memory _award = awards[_id];
        require(_award.usr != address(0), "DssVest/invalid-award");
        if (_end < block.timestamp) {
            _end = block.timestamp;
        }
        if (_end < _award.fin) {
            uint48 end = toUint48(_end);
            awards[_id].fin = end;
            if (end < _award.bgn) {
                awards[_id].bgn = end;
                awards[_id].clf = end;
                awards[_id].tot = 0;
            } else if (end < _award.clf) {
                awards[_id].clf = end;
                awards[_id].tot = 0;
            } else {
                awards[_id].tot = toUint128(
                                    add(
                                        unpaid(_end, _award.bgn, _award.clf, _award.fin, _award.tot, _award.rxd),
                                        _award.rxd
                                    )
                                );
            }
        }

        emit Yank(_id, _end);
    }

    /**
        @dev Allows owner to move a contract to a different address
        @param _id  The id of the vesting contract
        @param _dst The address to send ownership of the contract to
    */
    function move(uint256 _id, address _dst) external lock {
        require(awards[_id].usr == msg.sender, "DssVest/only-user-can-move");
        require(_dst != address(0), "DssVest/zero-address-invalid");
        awards[_id].usr = _dst;
        emit Move(_id, _dst);
    }

    /**
        @dev Return true if a contract is valid
        @param _id The id of the vesting contract
        @return isValid True for valid contract
    */
    function valid(uint256 _id) external view returns (bool isValid) {
        isValid = awards[_id].rxd < awards[_id].tot;
    }

    /**
        @dev Override this to implement payment logic.
        @param _guy The payment target.
        @param _amt The payment amount. [units are implementation-specific]
    */
    function pay(address _guy, uint256 _amt) virtual internal;
}

/*
    Transferrable token DssVest. Can be used to enable streaming payments of
     any arbitrary token from an address to individual contributors.
    MaseerVest uses safeTransferFrom to ensure non-standard tokens can be used.
*/
contract MaseerVest is DssVest {

    address public immutable czar;
    address public immutable gem;

    error TransferFailed();

    /**
        @dev This contract must be approved for transfer of the gem on the czar
        @param _czar The owner of the tokens to be distributed
        @param _gem  The token to be distributed
    */
    constructor(address _czar, address _gem) DssVest() {
        require(_czar != address(0), "MaseerVest/Invalid-distributor-address");
        require(_gem  != address(0), "MaseerVest/Invalid-token-address");
        czar = _czar;
        gem  = _gem;
    }

    /**
        @dev Override pay to handle transfer logic
        @param _guy The recipient of the ERC-20
        @param _amt The amount of gem to send to the _guy (in native token units)
    */
    function pay(address _guy, uint256 _amt) override internal {
        _safeTransferFrom(gem, czar, _guy, _amt);
    }

    function _safeTransferFrom(address _token, address _from, address _to, uint256 _amt) internal {
        (bool success, bytes memory data) = _token.call(abi.encodeWithSelector(Gem.transferFrom.selector, _from, _to, _amt));
        if (!success || (data.length > 0 && abi.decode(data, (bool)) == false)) revert TransferFailed();
    }
}
