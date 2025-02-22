module anto::maps {
    use std::signer::address_of;
    use anto::big_ordered_map;
    use anto::big_ordered_map::BigOrderedMap;

    struct Holder has key, store {
        ascending: BigOrderedMap<u64, Store>,
        descending: BigOrderedMap<u64, Store>
    }

    struct Store has key, store, drop {
        val: u64
    }

    const MAX_U64: u64 = 0xFFFFFFFFFFFFFFFF;

    fun init_module(dev: &signer) {

        let asmap = big_ordered_map::new<u64, Store>();
        let dsmap = big_ordered_map::new<u64, Store>();
        //
        // let keys = vector<u64>[20, 19, 2, 88, 4];
        // for (i in 0..keys.length()) {
        //     asmap.add(keys[i], Store{val: 1897})
        // };
        //
        // for (i in 0..keys.length()) {
        //     dsmap.add(MAX_U64 - keys[i], Store{val: 1897})
        // };

        move_to(dev, Holder {
            ascending: asmap,
            descending: dsmap
        })
    }

    fun get_as_key(k: u64): u64 {
        k
    }
    fun get_ds_key(k: u64): u64 {
        MAX_U64 - k
    }

    public fun add_to_map(caller: &signer, key: u64, val: u64, is_ascending: bool) acquires Holder {
        let holder = &mut Holder[address_of(caller)];
        if(is_ascending) {
            holder.ascending.add(get_as_key(key), Store{val})
        } else {
            holder.descending.add(get_ds_key(key), Store{val})
        }
    }

    public fun find_and_reduce(caller: &signer, key: u64, val: u64, is_ascending: bool) acquires Holder {
        let holder = &mut Holder[address_of(caller)];
        let remaining = val;
        let as_key = get_as_key(key);
        let ds_key = get_ds_key(key);
        if(is_ascending) {
            let contains = holder.ascending.contains(&as_key);
            if (contains) {
                let store = holder.ascending.borrow_mut(&as_key);
                if (remaining < store.val) {
                    store.val -= remaining;
                } else {
                    remaining -= store.val;
                    holder.ascending.remove(&as_key);
                };
            };
            if (remaining > 0) {
                holder.descending.add(ds_key, Store { val:remaining })
            }
        } else {
            let contains = holder.descending.contains(&ds_key);
            if (contains) {
                let store = holder.descending.borrow_mut(&ds_key);
                if (remaining < store.val) {
                    store.val -= remaining;
                } else {
                    remaining -= store.val;
                    holder.descending.remove(&ds_key);
                };
            };
            if (remaining > 0) {
                holder.ascending.add(as_key, Store { val:remaining })
            }
        }
    }

    #[test_only]
    use aptos_framework::account::create_account_for_test;

    #[test]
    fun test_add_and_reduce() acquires Holder {
        let acc = &create_account_for_test(@7001);
        init_module(acc);

        let key = 10;
        // add key to ascending
        add_to_map(acc, key, 1000, true);

        let holder= &Holder[address_of(acc)];
        // asc map should contain key
        assert!(holder.ascending.contains(&key));

        // reduce from ascending post to descending of not reduced fully
        find_and_reduce(acc, key, 2000, true);

        let holder= &Holder[address_of(acc)];
        // asc map shouldn't contain key
        assert!(!holder.ascending.contains(&key));

        // dsc map should contain key
        assert!(holder.descending.contains(&get_ds_key(key)));

        // aptos_std::debug::print(&std::string::utf8(b"as map"));
        // aptos_std::debug::print(&holder.ascending);
        // aptos_std::debug::print(&std::string::utf8(b"ds map"));
        // aptos_std::debug::print(&holder.descending);
    }
}
