# maseer-vest

A token vesting plan for contributors. Includes scheduling, cliff vesting, and third-party revocation.

### Mainnet

[0xd13e01574992bc4b4500d3e6a2b3c8fa61b2ac30](https://etherscan.io/address/0xd13e01574992bc4b4500d3e6a2b3c8fa61b2ac30)

### Requirements

- [Foundry](https://getfoundry.sh/)

### Deployment

`maseer-vest` allows DAOs to create a participant vesting plan from operational funds

#### MaseerVest

Pass the authorized sender address and the address of the token contract to the constructor to set up the contract for streaming arbitrary ERC20 tokens. Note: this contract must be given ERC `approve()` authority to withdraw tokens from this contract.

After deployment, the owner must also set the `cap` value using the `file` function.

### Creating a vest

#### `create(_usr, _tot, _bgn, _tau, _eta, _mgr) returns (id)`

Create a new vesting plan.

- `_usr`: The plan beneficiary
- `_tot`: The total amount of the vesting plan, in token units
  - ex. 100 USDT = `100 * 10**6`
- `_bgn`: A unix-timestamp of the plan start date
- `_tau`: The duration of the vesting plan (in seconds)
- `_eta`: The cliff period, a duration in seconds from the `_bgn` time, in which tokens are accrued but not payable. (in seconds)
- `_mgr`: (Optional) The address of an authorized manager. This address has permission to remove the vesting plan when the contributor leaves the project.
  - Note: `auth` users on this contract _always_ have the ability to `yank` a vesting contract.

### Interacting with a vest

#### `vest(_id)`

The vesting plan participant calls `vest(id)` after the cliff period to pay out all accrued and unpaid tokens.

#### `vest(_id, _maxAmt)`

The vesting plan participant calls `vest(id, maxAmt)` after the cliff period to pay out accrued and unpaid tokens, up to maxAmt.

#### `move(_id, _dst)`

The vesting plan participant can transfer their contract `_id` control and ownership to another address `_dst`.

#### `unpaid(_id) returns (amt)`

Returns the amount of accrued, vested, unpaid tokens.

#### `accrued(_id) returns (amt)`

Returns the amount of tokens that have accrued from the beginning of the plan to the current block.

#### `valid(_id) returns (bool)`

Returns true if the plan id is valid and has not been claimed or yanked before the cliff.

#### `restrict(uint256)`

Allows governance or the owner to restrict vesting to the owner only.

#### `unrestrict(uint256)`

Allows governance or the owner to enable permissionless vesting.

### Revoking a vest

#### `yank(_id)`

An authorized user (ex. governance) of the vesting contract, or an optional plan manager, can `yank` a vesting contract. If the contract is yanked prior to the plan cliff, no funds will be paid out. If a plan is `yank`ed after the contract cliff period has ended, new accruals will cease and the participant will be able to call `vest` to claim any vested funds.

#### `yank(_id, _end)`

Allows governance to schedule a point in the future to end the vest. Used for planned offboarding of contributors.
