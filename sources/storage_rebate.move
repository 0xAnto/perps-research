module anto::storage {
    use std::signer::address_of;
    use aptos_framework::object;
    use aptos_framework::object::DeleteRef;
    use anto::big_ordered_map;
    use anto::big_ordered_map::BigOrderedMap;

    struct Holder has key, store {
        map: BigOrderedMap<u64, Data>,
        count: u64
    }

    struct Data has key, store, drop {
        user: address,
        size: u64,
    }

    struct ObjectCtrl has key, store, drop {
        delete_ref: DeleteRef
    }

    fun init_module(dev: &signer) {
        move_to(dev, Holder {
            map: big_ordered_map::new<u64, Data>(),
            count: 0
        })
    }

    fun get_key(k: u64): u64 {
        k
    }

    public entry fun add_to_map(caller: &signer, key: u64, size: u64) acquires Holder {
        let caller_address = address_of(caller);
        let holder = &mut Holder[@anto];
        holder.map.add(get_key(key), Data{user: caller_address, size})
    }

    public entry fun remove_from_map(caller: &signer, key: u64) acquires Holder {
        let caller_address = address_of(caller);
        let holder = &mut Holder[@anto];
        if(holder.map.contains(&get_key(key))) {
            holder.map.remove(&get_key(key));
        }
    }

    public entry fun create_obj(caller: &signer)  {
        let caller_address = address_of(caller);
        let obj_const = object::create_object(caller_address);
        let delete_ref = object::generate_delete_ref(&obj_const);
        move_to(caller, ObjectCtrl {
            delete_ref
        });
    }

    public entry fun delete_obj(caller: &signer) acquires ObjectCtrl {
        let caller_address = address_of(caller);
        let ObjectCtrl{ delete_ref} = move_from<ObjectCtrl>(caller_address);
        object::delete(delete_ref);
    }
}