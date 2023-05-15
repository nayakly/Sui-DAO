#[test_only]
module dao::crowdFund_tests {

    use dao::crowdFund::{Self, Campaign, CampaignCap};
    use sui::test_scenario;
    use sui::clock;
    use sui::sui::SUI;
    use sui::coin;

    #[test]
    #[expected_failure(abort_code = crowdFund::ECampaignInProgress)]
    fun test_cancel_campaign(){
    
        let owner = @0x1;

        let scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let clock = clock::create_for_testing(ctx);

            crowdFund::launch(0, 5, 1000, &clock, ctx);
            clock::destroy_for_testing(clock);
        };
        test_scenario::next_tx(scenario, owner);
        {
            let ctx = test_scenario::ctx(scenario);
            let clock = clock::create_for_testing(ctx);
            clock::increment_for_testing(&mut clock, 2);

            let campaign = test_scenario::take_shared<Campaign>(scenario);
            let cap = test_scenario::take_from_sender<CampaignCap>(scenario);

            crowdFund::cancel(cap, &mut campaign, &clock);
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(campaign);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_successful_campaign(){

        let owner = @0x1;
        let user = @0x2;

        let scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let clock = clock::create_for_testing(ctx);

            crowdFund::launch(0, 5, 1000, &clock, ctx);
            clock::destroy_for_testing(clock);
        };

        test_scenario::next_tx(scenario, user);
        {
            // Syntax: Get Objects first 
            let campaign = test_scenario::take_shared<Campaign>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            let clock = clock::create_for_testing(ctx);
            let sui = coin::mint_for_testing<SUI>(1000, ctx);

            crowdFund::pledge(&mut campaign, sui, &clock, ctx);
            let donation_val = crowdFund::Total_Donation_Value(&campaign, user);
            assert!( donation_val == 1000, 100);

            test_scenario::return_shared(campaign);
            clock::destroy_for_testing(clock);
        };
        test_scenario::next_tx(scenario, owner);
        {
            // Syntax: Get Objects first 
            let campaign = test_scenario::take_shared<Campaign>(scenario);
            let cap = test_scenario::take_from_sender<CampaignCap>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            let clock = clock::create_for_testing(ctx);
            clock::increment_for_testing(&mut clock, 6);

            crowdFund::claim(&mut cap, &mut campaign, &clock, ctx);

            test_scenario::return_shared(campaign);
            test_scenario::return_to_sender(scenario, cap);
            clock::destroy_for_testing(clock);
        };
        test_scenario::end(scenario_val);
    }
}
