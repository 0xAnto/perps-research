module anto::big_ordered_map {
    use std::signer::address_of;
    use aptos_framework::big_ordered_map::{Self, BigOrderedMap};

    struct BigOrderedMapHolder has key, store {
        map: BigOrderedMap<u64, Data>,
        count: u64
    }

    struct Data has key, store, drop {
        user: address,
        value: u64,
    }

    public entry fun create_big_ordered_map(caller: &signer){
        move_to(caller, BigOrderedMapHolder {
            map: big_ordered_map::new<u64, Data>(),
            count: 0
        });
    }

    public entry fun delete_big_ordered_map(caller: &signer) acquires BigOrderedMapHolder {
        let BigOrderedMapHolder{
            map,
            count: _
        } = move_from<BigOrderedMapHolder>(address_of(caller));
        map.destroy_empty()
    }

    public entry fun add_to_big_ordered_map(caller: &signer, key: u64) acquires BigOrderedMapHolder {
        let caller_address = address_of(caller);
        let holder = &mut BigOrderedMapHolder[caller_address];
        holder.map.add(key, Data{user: caller_address, value:1000})
    }

    public entry fun add_multiple_to_big_ordered_map(caller: &signer, from: u64, to: u64) acquires BigOrderedMapHolder {
        while(from < to) {
            let key = from;
            let caller_address = address_of(caller);
            let holder = &mut BigOrderedMapHolder[caller_address];
            holder.map.add(key, Data{user: caller_address, value:1000});
            from += 1
        }
    }

    public entry fun remove_from_big_ordered_map(caller: &signer, key: u64) acquires BigOrderedMapHolder {
        let holder = &mut BigOrderedMapHolder[address_of(caller)];
        if(holder.map.contains(&key)) {
            holder.map.remove(&key);
        }
    }

    public entry fun remove_multiple_from_big_ordered_map(caller: &signer, from: u64, to: u64) acquires BigOrderedMapHolder {
        while(from < to) {
            let key = from;
            let holder = &mut BigOrderedMapHolder[ address_of(caller)];
            if(holder.map.contains(&key)) {
                holder.map.remove(&key);
            };
            from += 1
        }
    }

}