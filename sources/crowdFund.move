module dao::crowdFund{

    /*
    In the event that the campaign attains or surpasses its targeted goal, the campaign's owner will be granted the gathered funds once the campaign concludes. The campaign's conclusion is mandated to be within 90 days from the present time. Conversely, if the total amount of funds amassed falls below the goal after the conclusion of the campaign, then the supporters who made contributions to the campaign will be entitled to a refund.
    */

    use sui::object::{Self, ID, UID};
    use sui::clock::{Self, Clock};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::vec_map::{Self, VecMap};
    use sui::event;
    
    struct CampaignCap has key {
        id: UID,
        owner: address
    }

    struct Campaign has key {
       id: UID,
       startTime: u64,
       endTime: u64,
       creator: address,
       donors: VecMap<address,u64>,
       goal: u64,
       donation: u64,
       treasury: Balance<SUI>
    }

    /// Events
    
    struct Launch has copy, drop {
        campaign_id: ID,
        startTime: u64,
        endTime: u64,
        creator: address,
        goal: u64
    } 

    struct Cancel has copy, drop {
        campaign_id: ID
    }
    
    struct Pledge has copy, drop{
        campaign_id: ID,
        caller: address,
        amount: u64
    }

    struct Unpledge has copy, drop {
        campaign_id: ID,
        caller: address,
        amount: u64
    }

    struct Claim has copy, drop {
        campaign_id: ID
    }

    struct Refund has copy, drop {
        campaign_id: ID,
        caller: address,
        amount: u64
    }

    const ENotCreatorOfCampaign: u64 = 100;
    const ECampaignGoalReached: u64 = 101;
    const ECampaignNotEnded: u64 = 102;
    const EStartTimeLessThanCurrentTime: u64 = 103;
    const EStartTimeGreaterThanEndTime: u64 = 104;
    const EEndTimeGreaterThanNinetyDays: u64 = 105;
    const ECampaignInProgress: u64 = 106;
    const ECampaignEnded: u64 = 107;
    const EUserNotCampaignDonor: u64 = 108;
    const EUnpledgeAmountGreaterThanDeposit: u64 = 109;
    const ECampaignNotStarted: u64 = 110;
    const ECampaignGoalNotReached: u64 = 111;
    const ECampaignFundsClaimed: u64 = 112;

    public entry fun launch(startTime: u64, endTime: u64, goal: u64, clock: &Clock, ctx: &mut TxContext){

        /* Let user launch a campaign if
           - Campaign start time is set to greater than or equal to current time
           - Campaign end time is greater than campaign start time
           - Campaign end time is bound to 90 days from the current time 
        */
        assert!(startTime >= clock::timestamp_ms(clock), EStartTimeLessThanCurrentTime);
        assert!(endTime >= startTime, EStartTimeGreaterThanEndTime);
        assert!(endTime <= clock::timestamp_ms(clock) + 90 * 24 * 60 * 60 * 1000, EEndTimeGreaterThanNinetyDays);

        transfer::transfer(CampaignCap {
            id: object::new(ctx),
            owner: tx_context::sender(ctx)
        }, tx_context::sender(ctx));

        let id = object::new(ctx);

        event::emit(Launch{
            campaign_id: object::uid_to_inner(&id),
            startTime,
            endTime,
            creator: tx_context::sender(ctx),
            goal
        });
        
        transfer::share_object(Campaign {
            id,
            startTime,
            endTime,
            creator: tx_context::sender(ctx),
            donors: vec_map::empty<address, u64>(),
            goal,
            donation: 0,
            treasury: balance::zero(),
        });
    
    }

    public entry fun cancel (cap: CampaignCap, campaign: &mut Campaign, clock: &Clock) {
       
       /* Let creator of campaign cancel a campaign if
           - Campaign hasn't started yet 
        */
        assert!(cap.owner == campaign.creator, ENotCreatorOfCampaign);
        assert!(campaign.startTime > clock::timestamp_ms(clock), ECampaignInProgress);

        // Delete campaign owner cap
        let CampaignCap {id, owner: _} = cap;
        object::delete(id);

        // Modify campaign to invalidate it (shared object can't be deleted)
        campaign.startTime = 0;
        campaign.endTime = 0;

        event::emit(Cancel{campaign_id: object::uid_to_inner(&campaign.id) });
    }

    
    public entry fun pledge(campaign: &mut Campaign, payment: Coin<SUI>, clock: &Clock, ctx: &mut TxContext) {

        // Check if campaign is still in progress
        assert!(clock::timestamp_ms(clock) >= campaign.startTime, ECampaignNotStarted);
        assert!(clock::timestamp_ms(clock) <= campaign.endTime, ECampaignEnded);

        let donation_value = coin::value(&payment);
        let sender = tx_context::sender(ctx);

        // Add payment to campaign treasury
        let balance = coin::into_balance(payment);
        balance::join(&mut campaign.treasury, balance);

        // Add payment to donation variable
        campaign.donation = campaign.donation + donation_value;

        // Record donation in mapping
        if(vec_map::contains(&campaign.donors, &sender)){

            let pledge_amount = vec_map::get_mut(&mut campaign.donors, &sender);
            *pledge_amount = *pledge_amount + donation_value; 
        }
        else{
            vec_map::insert(&mut campaign.donors, sender, donation_value);
        };

        event::emit(Pledge{campaign_id: object::uid_to_inner(&campaign.id),
        caller: sender,
        amount: donation_value});
    }

    
    public entry fun unpledge(campaign: &mut Campaign, amount: u64, clock: &Clock, ctx: &mut TxContext) {

        // Check if campaign is still in progress
        assert!(clock::timestamp_ms(clock) >= campaign.startTime, ECampaignNotStarted);
        assert!(clock::timestamp_ms(clock) <= campaign.endTime, ECampaignEnded);

        let sender = tx_context::sender(ctx);
        
        // Check if user has donated to the campaign
        assert!(vec_map::contains(&campaign.donors, &sender), EUserNotCampaignDonor);

        let pledged_amount = vec_map::get_mut(&mut campaign.donors, &sender);

        //Check if amount to be umpleged is less than or equal to the pledged amount by the user
        assert!(amount <= *pledged_amount, EUnpledgeAmountGreaterThanDeposit);

        // Subtract user balance from mapping
        *pledged_amount = *pledged_amount - amount;

        // Subtract amount from donation variable
        campaign.donation = campaign.donation - amount;

        // Transfer coins to user
        let coin = coin::take(&mut campaign.treasury, amount, ctx);
        transfer::public_transfer(coin, tx_context::sender(ctx));

        event::emit(Unpledge{
        campaign_id: object::uid_to_inner(&campaign.id),
        caller: sender,
        amount: amount});
    }


    public entry fun claim(cap : &mut CampaignCap, campaign: &mut Campaign, clock: &Clock, ctx: &mut TxContext){  

        /* let campaign owner withdraw funds only if
           - Campaign has ended
           - Goal amount has been reached or exceeded
           - Funds haven't been withdrawn (Balance<SUI> != 0)
        */

        assert!(cap.owner == campaign.creator, ENotCreatorOfCampaign);
        assert!(clock::timestamp_ms(clock) > campaign.endTime, ECampaignNotEnded);

        let treasury = balance::value(&campaign.treasury);

        assert!(campaign.donation >= campaign.goal, ECampaignGoalNotReached);
        assert!(treasury != 0, ECampaignFundsClaimed);

        let profits = coin::take(&mut campaign.treasury, treasury, ctx);
        transfer::public_transfer(profits, tx_context::sender(ctx));

        event::emit(Claim{campaign_id: object::uid_to_inner(&campaign.id)});
    }

    
    public entry fun refund(campaign: &mut Campaign, clock: &Clock, ctx: &mut TxContext) {

        // Check if campaign has ended 
        assert!(clock::timestamp_ms(clock) > campaign.endTime, ECampaignNotEnded);

        // Check if campaign goal hasn't been reached
        assert!(campaign.donation < campaign.goal, ECampaignGoalReached);

        let sender = tx_context::sender(ctx);
        
        // Check if user has donated to the campaign
        assert!(vec_map::contains(&campaign.donors, &sender), EUserNotCampaignDonor);

        let pledged_amount = vec_map::get_mut(&mut campaign.donors, &sender);

        // Subtract from donation variable
        campaign.donation = campaign.donation - *pledged_amount;

        // Store user balance in temp variable to emit event
        let amount = *pledged_amount;

        // Subtract user balance from mapping
        *pledged_amount = 0;

        // Transfer coins to user
        let coin = coin::take(&mut campaign.treasury, *pledged_amount, ctx);
        transfer::public_transfer(coin, tx_context::sender(ctx));

        event::emit(Refund{
            campaign_id: object::uid_to_inner(&campaign.id),
            caller: sender,
            amount
        });
    }

    // Read Functions
    #[test_only]
    public entry fun Total_Donation_Value(campaign: &Campaign, donor: address): u64 {
        *vec_map::get(&campaign.donors, &donor)
    }

}