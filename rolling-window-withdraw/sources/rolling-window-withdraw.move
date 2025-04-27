module anto::rolling_window_withdraw {

    use std::signer;
    use std::timestamp;
    use std::vector;
    use aptos_std::debug::print;
    #[test_only]
    use aptos_framework::account::create_account_for_test;

    /// Global limit reached
    const E_GLOBAL_LIMIT_REACHED: u64 = 12001;
    /// User limit reached
    const E_USER_LIMIT_REACHED: u64 = 12002;

    // const TIME_WINDOW: u64 = 86400; // 24 hours in seconds
    const TIME_WINDOW: u64 = HOUR * BUCKET_COUNT; // 24 hours in seconds
    const HOUR: u64 = 3600; // 1 hour in seconds
    const BUCKET_COUNT: u64 = 4; // no of buckets
    const MAX_USER_WITHDRAWAL: u64 = 25_000_000_000; // $25,000 in decimals

    struct Bucket has store, copy, drop {
        timestamp: u64,
        amount: u64,
    }

    struct GlobalWithdrawals has key {
        buckets: vector<Bucket>,
        total: u64, // cached total within last 24 hours
    }

    struct UserWithdrawals has key {
        buckets: vector<Bucket>,
        total: u64, // cached user total within last 24 hours
    }

    public fun init(account: &signer) {
        let global = GlobalWithdrawals {
            buckets: vector::empty<Bucket>(),
            total: 0,
        };

        let i = 0;
        while (i < BUCKET_COUNT) {
            global.buckets.push_back(Bucket { timestamp: 0, amount: 0 });
            i += 1;
        };

        move_to(account, global);
    }

    fun init_user_if_needed(account: &signer) {
        let addr = signer::address_of(account);
        if (!exists<UserWithdrawals>(addr)) {
            let buckets = vector::empty<Bucket>();
            let i = 0;
            while (i < BUCKET_COUNT) {
                buckets.push_back(Bucket { timestamp: 0, amount: 0 });
                i += 1;
            };
            move_to(account, UserWithdrawals {
                buckets,
                total: 0,
            });
        }
    }

    fun refresh_total(buckets: &mut vector<Bucket>, total_ref: &mut u64, now: u64) {
        let i = 0;
        while (i < BUCKET_COUNT) {
            let bucket = buckets.borrow_mut(i);
            if (now - bucket.timestamp >= TIME_WINDOW && bucket.amount > 0) {
                *total_ref -= bucket.amount;
                bucket.amount = 0;
                bucket.timestamp = 0;
            };
            i += 1;
        }
    }

    fun update_bucket(buckets: &mut vector<Bucket>, total_ref: &mut u64, amount: u64, now: u64) {
        let hour_index = (now / HOUR) % BUCKET_COUNT;
        print(&hour_index);
        let bucket = buckets.borrow_mut(hour_index);

        if (now - bucket.timestamp >= TIME_WINDOW) {
            // expired: reset and subtract old
            *total_ref -= bucket.amount;
            *bucket = Bucket { timestamp: now, amount };
        } else {
            // still valid: add to same bucket
            bucket.amount += amount;
        };

        bucket.timestamp = now;
        *total_ref += amount;
    }

    public fun request_withdrawal(user: &signer, amount: u64) acquires GlobalWithdrawals, UserWithdrawals {
        let now = timestamp::now_seconds();

        let tvl = available_tvl();
        let max_global = tvl / 10; // 10% of TVL

        let global_ref = borrow_global_mut<GlobalWithdrawals>(@0x1000);
        // print(global_ref);
        refresh_total(&mut global_ref.buckets, &mut global_ref.total, now);
        // print(global_ref);
        assert!(global_ref.total + amount <= max_global, E_GLOBAL_LIMIT_REACHED); // global limit

        init_user_if_needed(user);
        let user_addr = signer::address_of(user);
        let user_ref = borrow_global_mut<UserWithdrawals>(user_addr);
        // print(user_ref);
        refresh_total(&mut user_ref.buckets, &mut user_ref.total, now);
        // print(user_ref);
        print(&(user_ref.total + amount));
        assert!(user_ref.total + amount <= MAX_USER_WITHDRAWAL, E_USER_LIMIT_REACHED); // user limit

        // Update both global and user buckets
        update_bucket(&mut global_ref.buckets, &mut global_ref.total, amount, now);
        update_bucket(&mut user_ref.buckets, &mut user_ref.total, amount, now);
    }

    fun available_tvl(): u64 { 500_000_000_000u64} // $100,000 //max global limit $10,000


    #[test_only]
    public fun init_test() {
        let aptos = &create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(aptos);
    }


    #[test]
    public fun test_single_withdrawal_within_time_window() acquires GlobalWithdrawals, UserWithdrawals {
        init_test();
        let admin = @0x1000;
        let user1 = @0x2000;
        let withdraw_amount = 5_000_000_000;// $5,000 withdrawal

        init(&create_account_for_test(admin));

        request_withdrawal(&create_account_for_test(user1), withdraw_amount);

        let global = borrow_global<GlobalWithdrawals>(admin);
        let user_wd = borrow_global<UserWithdrawals>(user1);
        assert!(global.total == withdraw_amount, 0);
        assert!(user_wd.total == withdraw_amount, 1);
    }
    #[test]
    public fun test_multiple_withdrawal_within_time_window() acquires GlobalWithdrawals, UserWithdrawals {
        init_test();
        let admin = @0x1000;
        let user1 = @0x2000;
        let withdraw_amount = 5_000_000_000;// $5,000 withdrawal

        init(&create_account_for_test(admin));

        request_withdrawal(&create_account_for_test(user1), withdraw_amount);
        timestamp::fast_forward_seconds(HOUR);
        request_withdrawal(&create_account_for_test(user1), withdraw_amount);
        timestamp::fast_forward_seconds(HOUR);
        request_withdrawal(&create_account_for_test(user1), withdraw_amount);
        timestamp::fast_forward_seconds(HOUR);
        request_withdrawal(&create_account_for_test(user1), withdraw_amount);
        request_withdrawal(&create_account_for_test(user1), withdraw_amount);

        let global = borrow_global<GlobalWithdrawals>(admin);
        let user_wd = borrow_global<UserWithdrawals>(user1);

        assert!(global.total == withdraw_amount * 5, 0);
        assert!(user_wd.total == withdraw_amount * 5, 1);
    }

    #[test]
    #[expected_failure(abort_code = E_USER_LIMIT_REACHED)]
    public fun test_exceed_user_limit() acquires GlobalWithdrawals, UserWithdrawals {
        init_test();
        let admin = @0x1000;
        let user1 = @0x2000;
        let withdraw_amount = 5_000_000_000;// $5,000 withdrawal

        init(&create_account_for_test(admin));

        request_withdrawal(&create_account_for_test(user1), withdraw_amount * 10 );

        let global = borrow_global<GlobalWithdrawals>(admin);
        let user_wd = borrow_global<UserWithdrawals>(user1);

        assert!(global.total == withdraw_amount * 5, 0);
        assert!(user_wd.total == withdraw_amount * 5, 1);
    }

    #[test]
    public fun test_multiple_user_within_global_limit() acquires GlobalWithdrawals, UserWithdrawals {
        init_test();
        let admin = @0x1000;
        let user1 = @0x2000;
        let user2 = @0x2001;
        let withdraw_amount = 5_000_000_000;// $5,000 withdrawal

        init(&create_account_for_test(admin));

        request_withdrawal(&create_account_for_test(user1), withdraw_amount * 5 );
        request_withdrawal(&create_account_for_test(user2), withdraw_amount * 5 );

        let global = borrow_global<GlobalWithdrawals>(admin);

        assert!(global.total == withdraw_amount * 10, 0);
    }

    #[test]
    #[expected_failure(abort_code = E_GLOBAL_LIMIT_REACHED)]
    public fun test_multiple_user_exceed_global_limit() acquires GlobalWithdrawals, UserWithdrawals {
        init_test();
        let admin = @0x1000;
        let user1 = @0x2000;
        let user2 = @0x2001;
        let user3 = @0x2002;
        let withdraw_amount = 5_000_000_000;// $5,000 withdrawal

        init(&create_account_for_test(admin));

        request_withdrawal(&create_account_for_test(user1), withdraw_amount * 5 );
        request_withdrawal(&create_account_for_test(user2), withdraw_amount * 5 );
        request_withdrawal(&create_account_for_test(user3), withdraw_amount * 5 );
    }


    #[test]
    public fun test_rolling_window_expiry() acquires GlobalWithdrawals, UserWithdrawals {
        init_test();
        let admin = @0x1000;
        let user1 = @0x2000;

        let withdraw_amount = 5_000_000_000;// $5,000 withdrawal

        init(&create_account_for_test(admin));

        // Step 1: First withdrawal
        request_withdrawal(&create_account_for_test(user1), withdraw_amount);
        timestamp::fast_forward_seconds(HOUR);
        request_withdrawal(&create_account_for_test(user1), withdraw_amount);
        timestamp::fast_forward_seconds(HOUR);
        request_withdrawal(&create_account_for_test(user1), withdraw_amount);
        timestamp::fast_forward_seconds(HOUR);
        request_withdrawal(&create_account_for_test(user1), withdraw_amount);
        request_withdrawal(&create_account_for_test(user1), withdraw_amount);
        timestamp::fast_forward_seconds(HOUR);
        print(&timestamp::now_seconds());
        // Step 2: Advance 24 hours + 1 second
        timestamp::fast_forward_seconds( 1);
        print(&timestamp::now_seconds());

        // Step 3: Withdraw again after old window expires
        request_withdrawal(&create_account_for_test(user1), withdraw_amount);
        // timestamp::fast_forward_seconds(HOUR);
        // request_withdrawal(&create_account_for_test(user1), withdraw_amount);
        // timestamp::fast_forward_seconds(HOUR);
        // request_withdrawal(&create_account_for_test(user1), withdraw_amount);
        // timestamp::fast_forward_seconds(HOUR);
        // request_withdrawal(&create_account_for_test(user1), withdraw_amount);
        // request_withdrawal(&create_account_for_test(user1), withdraw_amount);

        let global = borrow_global<GlobalWithdrawals>(admin);
        let user_ref = borrow_global<UserWithdrawals>(user1);
        assert!(global.total == withdraw_amount * 5, 0);
        assert!(user_ref.total == withdraw_amount * 5, 0);
    }
}


