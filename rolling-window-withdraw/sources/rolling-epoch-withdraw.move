module anto::rolling_epoch_withdraw {
    use std::signer::address_of;
    use std::timestamp;
    use std::vector;
    #[test_only]
    use aptos_framework::account::create_account_for_test;

    /// Global limit reached
    const E_GLOBAL_LIMIT_REACHED: u64 = 12001;
    /// User limit reached
    const E_USER_LIMIT_REACHED: u64 = 12002;

    const HOUR: u64 = 3600; // 1 hour in seconds
    const BUCKET_COUNT: u64 = 4; // 4 hours
    const TIME_WINDOW: u64 = HOUR * BUCKET_COUNT; // 4 hours in seconds
    const MAX_USER_WITHDRAWAL: u64 = 25_000_000_000; // $25,000 in decimals

    struct Bucket has copy, drop, store {
        amount: u64,
    }

    struct GlobalWithdrawals has key {
        buckets: vector<Bucket>, // Only amounts now
        total: u64, // cached global total within last 24 hours
        last_updated_epoch: u64,
    }


    struct UserWithdrawals has key {
        buckets: vector<Bucket>,
        total: u64, // cached user total within last 24 hours
        last_updated_epoch: u64,
    }

    public fun init(account: &signer) {
        move_to(account, GlobalWithdrawals {
            buckets: create_buckets(),
            total: 0,
            last_updated_epoch: timestamp::now_seconds() / HOUR
        });
    }

    #[view]
    /// Returns the remaining withdrawal limit for a user in the current 24h window
    public fun get_user_remaining_limit(user: address): u64 acquires UserWithdrawals {
        let now = timestamp::now_seconds();

        let user_ref = borrow_global_mut<UserWithdrawals>(user);
        refresh_bucket(&mut user_ref.buckets, &mut user_ref.total, &mut user_ref.last_updated_epoch, now);

        if (user_ref.total >= MAX_USER_WITHDRAWAL) {
            0
        } else {
            MAX_USER_WITHDRAWAL - user_ref.total
        }
    }

    #[view]
    /// Returns the remaining global withdrawal limit in the current 24h window
    public fun get_global_remaining_limit(): u64 acquires GlobalWithdrawals {
        let now = timestamp::now_seconds();

        let global_ref = borrow_global_mut<GlobalWithdrawals>(@0x1000);
        refresh_bucket(&mut global_ref.buckets, &mut global_ref.total, &mut global_ref.last_updated_epoch, now);

        let max_global = available_tvl() / 10;

        if (global_ref.total >= max_global) {
            0
        } else {
            max_global - global_ref.total
        }
    }


    fun init_user_if_needed(account: &signer) {
        if (!exists<UserWithdrawals>(address_of(account))) {
            move_to(account, UserWithdrawals {
                buckets: create_buckets(),
                total: 0,
                last_updated_epoch: timestamp::now_seconds() / HOUR
            });
        }
    }
    public fun create_buckets(): vector<Bucket> {
        let buckets = vector::empty<Bucket>();
        let i = 0;
        while (i < BUCKET_COUNT) {
            buckets.push_back(Bucket { amount: 0 });
            i += 1;
        };
        buckets
    }

    fun refresh_bucket(buckets: &mut vector<Bucket>, total_ref: &mut u64, last_updated_epoch: &mut u64, now: u64) {
        let epoch = now / HOUR;
        // already fresh, nothing to do;
        if (*last_updated_epoch == epoch) return;
        let new_bucket_index = epoch % BUCKET_COUNT;
        if (epoch - *last_updated_epoch >= BUCKET_COUNT) {
            // More than 24h gap so clear all
            let i = 0;
            while (i < BUCKET_COUNT) {
                buckets.borrow_mut(i).amount = 0;
                i += 1;
            };
            *total_ref = 0;
        } else {
            // Only clear buckets between last_updated_epoch and current epoch
            let i = (*last_updated_epoch + 1) % BUCKET_COUNT;
            while (i != new_bucket_index) {
                let b = buckets.borrow_mut(i);
                *total_ref -= b.amount;
                b.amount = 0;
                i += 1;
                if (i == BUCKET_COUNT) i = 0;
            };
            let b = buckets.borrow_mut(new_bucket_index);
            *total_ref -= b.amount;
            b.amount = 0;
        };
        *last_updated_epoch = epoch;
    }

    public fun request_withdrawal(user: &signer, amount: u64) acquires GlobalWithdrawals, UserWithdrawals {
        let now = timestamp::now_seconds();

        let tvl = available_tvl();
        let max_global = tvl / 10; // 10% of TVL

        let global_ref = borrow_global_mut<GlobalWithdrawals>(@0x1000);
        refresh_bucket(&mut global_ref.buckets, &mut global_ref.total, &mut global_ref.last_updated_epoch, now);
        assert!(global_ref.total + amount <= max_global, E_GLOBAL_LIMIT_REACHED); // global limit

        init_user_if_needed(user);
        let user_ref = borrow_global_mut<UserWithdrawals>(address_of(user));
        refresh_bucket(&mut user_ref.buckets, &mut user_ref.total, &mut user_ref.last_updated_epoch, now);
        assert!(user_ref.total + amount <= MAX_USER_WITHDRAWAL, E_USER_LIMIT_REACHED); // user limit

        let epoch = now / HOUR;
        let bucket_idx = epoch % BUCKET_COUNT;

        let bucket = global_ref.buckets.borrow_mut(bucket_idx);
        bucket.amount += amount;
        global_ref.total += amount;

        let user_bucket = user_ref.buckets.borrow_mut(bucket_idx);
        user_bucket.amount += amount;
        user_ref.total += amount;
    }

    fun available_tvl(): u64 { 500_000_000_000u64} // $500,000 //max global limit $50,000


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
        request_withdrawal(&create_account_for_test(user1), withdraw_amount * 2);
        timestamp::fast_forward_seconds(HOUR);
        request_withdrawal(&create_account_for_test(user1), withdraw_amount);
        timestamp::fast_forward_seconds(HOUR);
        request_withdrawal(&create_account_for_test(user1), withdraw_amount);
        timestamp::fast_forward_seconds(HOUR);
        request_withdrawal(&create_account_for_test(user1), withdraw_amount);
        timestamp::fast_forward_seconds(HOUR + 1);
        // Step 2: Withdraw again after old window expires
        request_withdrawal(&create_account_for_test(user1), withdraw_amount);

        let global = borrow_global<GlobalWithdrawals>(admin);
        let user_ref = borrow_global<UserWithdrawals>(user1);
        assert!(global.total == withdraw_amount * 4, 0);
        assert!(user_ref.total == withdraw_amount * 4, 0);
    }

    #[test]
    fun test_clear_first_bucket_after_window_rollover() acquires GlobalWithdrawals, UserWithdrawals {
        init_test();
        let admin = @0x1000;
        let user1 = @0x2000;
        let withdraw_amount = 5_000_000_000;// $5,000 withdrawal
        init(&create_account_for_test(admin));

        // withdrawal in hour 0
        request_withdrawal(&create_account_for_test(user1), withdraw_amount);
        // withdrawals in all hours
        let h = 1;
        while (h < BUCKET_COUNT) {
            timestamp::fast_forward_seconds(HOUR);
            request_withdrawal(&create_account_for_test(user1), withdraw_amount);
            h += 1;
        };
        // Move to next window, hour 0
        timestamp::fast_forward_seconds(HOUR + 1);
        // Withdraw in new window, it should not exceed limits
        request_withdrawal(&create_account_for_test(user1), withdraw_amount);

    }

}
