# **DAO Smart Contract**

This package is a library of DAO-related functions that can be used to develop smart contracts on the Sui network.

## **Functions**
This library includes several functions that can be used to implement various DAO-related features, including:

- **Crowdfunding**: A function that enables the creation of crowdfunding campaigns and the collection of funds from multiple users.

- **Multi-Sig Wallet**: A function that allows multiple users to control a single wallet, requiring a specified number of users to approve transactions.

- **Time Lock**: A function that enables the automatic execution of certain transactions after a specified time period.

- **Voting**: A function that enables the creation of voting systems for decision making within the DAO.

- **Membership Management**: A function that enables the management of membership within the DAO, including adding and removing members and assigning roles.

## **Overview**

To navigate through the overview of different contracts, utilize the toggle feature. Please note that the additional contracts will be incorporated at a later stage.

<details>
    <summary>CrowdFund</summary>



 **`Campaign`** is a struct that represents a campaign and has the following fields: 

- **`id`**: A unique identifier for the campaign, represented as a UID.
- **`startTime`**: A Unix timestamp representing the start time of the campaign.
- **`endTime`**: A Unix timestamp representing the end time of the campaign.
- **`creator`**: The address of the user who created the campaign.
- **`donors`**: A data structure that maps addresses to the amount of funds donated by each donor. 
- **`goal`**: The fundraising goal of the campaign, represented as an unsigned 64-bit integer (`u64`).
- **`donation`**: The total amount of funds donated to the campaign so far, represented as an unsigned 64-bit integer (`u64`).
- **`treasury`**: The balance of funds held in the campaign's treasury, represented as a Balance type parameterized with the SUI coin. 

In addition, the **`CampaignCap`** struct represents a capability owned by the campaign creator, allowing them to cancel the campaign before it starts and access to the funds raised after successful completion.

The contract includes the following functions:

## `launch`

This function creates a new campaign with the given **`startTime`**, **`endTime`**, and **`goal`**. The campaign creator is the caller of this function. The **`clock`** parameter provides the current timestamp, and **`ctx`** provides information about the transaction. The function will fail if:

- **`startTime`** is less than the current time.
- **`endTime`** is less than startTime.
- **`endTime`** is more than 90 days in the future.

```rust
public entry fun launch(startTime: u64, endTime: u64, goal: u64, clock: &Clock, ctx: &mut TxContext)
```

If the function succeeds, it will emit a **`Launch`** event with information about the new campaign.

## `cancel`

This function allows the creator of a campaign to cancel it before it starts. The **`cap`** parameter is a **`CampaignCap`** object that identifies the campaign by its unique ID and the address of the creator. The **`campaign`** parameter is a mutable reference to the **`Campaign`** object associated with the campaign. The **`clock`** parameter provides the current timestamp. The function will fail if:

- The **`cap`** object does not match the creator of the campaign.
- The campaign has already started.

```rust
public entry fun cancel(cap: CampaignCap, campaign: &mut Campaign, clock: &Clock)
```

If the function succeeds, it will cancel the campaign and emit a **`Cancel`** event with the **`ID`** of the canceled campaign.

## `pledge`

This function allows a user to pledge funds to a campaign. The **`campaign`** parameter is a mutable reference to the **`Campaign`** object associated with the campaign. The payment parameter is a **`Coin<SUI>`** object representing the amount of funds being pledged. The **`clock`** parameter provides the current timestamp, and **`ctx`** provides information about the transaction. The function will fail if:

- The campaign has not started yet.
- The campaign has already ended.

```rust
public entry fun pledge(campaign: &mut Campaign, payment: Coin<SUI>, clock: &Clock, ctx: &mut TxContext)
```

If the function succeeds, it will update the donors field of the campaign to record the pledge, and emit a **`Pledge`** event with information about the pledge.

## `unpledge`

This function allows a user to withdraw a previously made pledge. The **`campaign`** parameter is a mutable reference to the **`Campaign`** object associated with the campaign. The **`amount`** parameter is the amount of funds being withdrawn. The **`clock`** parameter provides the current timestamp, and **`ctx`** provides information about the transaction. The function will fail if:

- The campaign has already ended.
- The user has not made a pledge to the campaign.
- The **`amount`** parameter is greater than the user's current pledge.

```rust
public entry fun unpledge(campaign: &mut Campaign, amount: u64, clock: &Clock, ctx: &mut TxContext)
```

If the function succeeds, it will update the donors field of the campaign to reflect the withdrawal, and emit an **`Unpledge`** event.

## `claim`

This function allows the campaign owner to withdraw funds from the campaign treasury only if the following conditions are met:

- The campaign has ended
- The goal amount has been reached or exceeded
- Funds haven't been withdrawn yet (**`Balance<SUI>`** != 0)

If the function succeeds, it will transfer the funds from the campaign treasury to the owner's account and emit a **`Claim`** event.

```rust
public entry fun claim(cap : &mut CampaignCap, campaign: &mut Campaign, clock: &Clock, ctx: &mut TxContext)
```

## `refund`

This function allows a user who has donated to a campaign to request a refund if the following conditions are met:

- The campaign has ended
- The goal amount has not been reached
- The user has donated to the campaign

```rust
public entry fun refund(campaign: &mut Campaign, clock: &Clock, ctx: &mut TxContext)
```

If the function succeeds, it will update the donors field of the campaign to reflect the refund and emit a **`Refund`** event.

</details>
<br>

## **Contract Compilation & Testing**

To compile the contract, execute the following command in the root directory of the project:

```rust
sui move build
```

This will generate the compiled bytecode of the contract. To test the contract, there are test cases located in `./tests`. You can run the tests by executing the following command in the root directory of the project:

```rust
sui move test
```

## **Deployment**

To deploy the smart contract, please follow these steps:

1. Set your Sui client to the desired network (mainnet/testnet/devnet).
2. Navigate to the root directory of the smart contract.
3. Ensure that you have sufficient gas balance for the deployment.
4. Type the following command, replacing `<gas-value>` with the desired amount of gas

    ```rust
    sui client --publish --gas-budget <gas-value>
    ```

## **Usage**

The contract is designed to be used in conjunction with a user interface, such as a web application. When a user performs an action on their to-do list, such as adding or editing a task, the user interface should call the corresponding function on the smart contract.