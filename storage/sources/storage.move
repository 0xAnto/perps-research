module anto::storage {
    use std::signer::address_of;
    use std::vector;
    use aptos_std::table_with_length;
    use aptos_std::table_with_length::TableWithLength;
    use aptos_framework::object;
    use aptos_framework::object::DeleteRef;
    use aptos_framework::ordered_map;
    use aptos_framework::ordered_map::OrderedMap;
    use aptos_framework::big_ordered_map;
    use aptos_framework::big_ordered_map::BigOrderedMap;

    struct BigOrderedMapHolder has key, store {
        map: BigOrderedMap<u64, Data>,
        count: u64
    }


    struct OrderedMapHolder has key, store {
        map: OrderedMap<u64, Data>,
        count: u64
    }

    struct TableHolder has key, store {
        tab: TableWithLength<u64, Data>,
        count: u64
    }

    struct VectorHolder has key, store {
        vec: vector<Data>,
        count: u64
    }

    struct Data has key, store, drop {
        user: address,
        value: u64,
    }

    struct ObjectCtrl has key, store, drop {
        delete_ref: DeleteRef
    }

    // {
    //   "execution_gas_units": "4",
    //   "io_gas_units": "1",
    //   "storage_fee_octas": "46680",
    //   "storage_fee_refund_octas": "0",
    //   "total_charge_gas_units": "471"
    // }
    public entry fun create_big_ordered_map(caller: &signer){
        move_to(caller, BigOrderedMapHolder {
            map: big_ordered_map::new<u64, Data>(),
            count: 0
        });
    }

    // {
    //   "execution_gas_units": "4",
    //   "io_gas_units": "2",
    //   "storage_fee_octas": "0",
    //   "storage_fee_refund_octas": "46680",
    //   "total_charge_gas_units": "5"
    // }
    public entry fun delete_big_ordered_map(caller: &signer) acquires BigOrderedMapHolder {
        let caller_address = address_of(caller);
        let BigOrderedMapHolder{
            map,
            count: _
        } = move_from<BigOrderedMapHolder>(caller_address);
        map.destroy_empty()
    }

    // {
    //   "execution_gas_units": "3",
    //   "io_gas_units": "1",
    //   "storage_fee_octas": "44040",
    //   "storage_fee_refund_octas": "0",
    //   "total_charge_gas_units": "444"
    // }
    public entry fun create_ordered_map(caller: &signer){
        move_to(caller, OrderedMapHolder {
            map: ordered_map::new<u64, Data>(),
            count: 0
        });
    }

    // {
    //   "execution_gas_units": "3",
    //   "io_gas_units": "2",
    //   "storage_fee_octas": "0",
    //   "storage_fee_refund_octas": "44040",
    //   "total_charge_gas_units": "4"
    // }
    public entry fun delete_ordered_map(caller: &signer) acquires OrderedMapHolder {
        let caller_address = address_of(caller);
        let OrderedMapHolder{
            map,
            count: _
        } = move_from<OrderedMapHolder>(caller_address);
        map.destroy_empty()
    }

    // {
    //   "execution_gas_units": "3",
    //   "io_gas_units": "1",
    //   "storage_fee_octas": "45360",
    //   "storage_fee_refund_octas": "0",
    //   "total_charge_gas_units": "457"
    // }
    public entry fun create_table(caller: &signer){
        move_to(caller, TableHolder {
            tab: table_with_length::new<u64, Data>(),
            count: 0
        });
    }

    // {
    //   "execution_gas_units": "3",
    //   "io_gas_units": "2",
    //   "storage_fee_octas": "0",
    //   "storage_fee_refund_octas": "45360",
    //   "total_charge_gas_units": "5"
    // }
    public entry fun delete_table(caller: &signer) acquires TableHolder {
        let caller_address = address_of(caller);
        let TableHolder{ tab, count: _} = move_from<TableHolder>(caller_address);
        tab.destroy_empty()
    }

    // {
    //   "execution_gas_units": "3",
    //   "io_gas_units": "1",
    //   "storage_fee_octas": "43840",
    //   "storage_fee_refund_octas": "0",
    //   "total_charge_gas_units": "442"
    // }
    public entry fun create_vector(caller: &signer){
        move_to(caller, VectorHolder {
            vec: vector::empty<Data>(),
            count: 0
        });
    }

    // {
    //   "execution_gas_units": "3",
    //   "io_gas_units": "2",
    //   "storage_fee_octas": "0",
    //   "storage_fee_refund_octas": "43840",
    //   "total_charge_gas_units": "4"
    // }
    public entry fun delete_vector(caller: &signer) acquires VectorHolder {
        let caller_address = address_of(caller);
        let VectorHolder{
            vec,
            count: _
        } = move_from<VectorHolder>(caller_address);
        vec.destroy_empty();
    }

    // {
    //   "execution_gas_units": "4",
    //   "io_gas_units": "1",
    //   "storage_fee_octas": "93760",
    //   "storage_fee_refund_octas": "0",
    //   "total_charge_gas_units": "942"
    // }
    public entry fun create_obj(caller: &signer)  {
        let caller_address = address_of(caller);
        let obj_const = object::create_object(caller_address);
        let delete_ref = object::generate_delete_ref(&obj_const);
        move_to(caller, ObjectCtrl {
            delete_ref
        });
    }

    // {
    //   "execution_gas_units": "3",
    //   "io_gas_units": "3",
    //   "storage_fee_octas": "0",
    //   "storage_fee_refund_octas": "93760",
    //   "total_charge_gas_units": "6"
    // }
    public entry fun delete_obj(caller: &signer) acquires ObjectCtrl {
        let caller_address = address_of(caller);
        let ObjectCtrl{ delete_ref} = move_from<ObjectCtrl>(caller_address);
        object::delete(delete_ref);
    }

    // {
    //   "execution_gas_units": "4",
    //   "io_gas_units": "2",
    //   "storage_fee_octas": "1960",
    //   "storage_fee_refund_octas": "0",
    //   "total_charge_gas_units": "24"
    // }
    public entry fun add_to_big_ordered_map(caller: &signer, key: u64) acquires BigOrderedMapHolder {
        let caller_address = address_of(caller);
        let holder = &mut BigOrderedMapHolder[caller_address];
        holder.map.add(key, Data{user: caller_address, value:1000})
    }

    public entry fun add_multiple_to_big_ordered_map(caller: &signer, key: u64, count: u64) acquires BigOrderedMapHolder {
        while(count > 0) {
            let key = key + count;
            let caller_address = address_of(caller);
            let holder = &mut BigOrderedMapHolder[caller_address];
            holder.map.add(key, Data{user: caller_address, value:1000});
            count -= 1
        }
    }

    // {
    //   "execution_gas_units": "4",
    //   "io_gas_units": "2",
    //   "storage_fee_octas": "0",
    //   "storage_fee_refund_octas": "0",
    //   "total_charge_gas_units": "5"
    // }
    public entry fun remove_from_big_ordered_map(caller: &signer, key: u64) acquires BigOrderedMapHolder {
        let caller_address = address_of(caller);
        let holder = &mut BigOrderedMapHolder[caller_address];
        if(holder.map.contains(&key)) {
            holder.map.remove(&key);
        }
    }

    public entry fun remove_multiple_from_big_ordered_map(caller: &signer, key: u64, count: u64) acquires BigOrderedMapHolder {
        while(count > 0) {
            let key = key + count;
            let caller_address = address_of(caller);
            let holder = &mut BigOrderedMapHolder[caller_address];
            if(holder.map.contains(&key)) {
                holder.map.remove(&key);
            };
            count -= 1
        }
    }

    // {
    //   "execution_gas_units": "4",
    //   "io_gas_units": "2",
    //   "storage_fee_octas": "1920",
    //   "storage_fee_refund_octas": "0",
    //   "total_charge_gas_units": "24"
    // }
    public entry fun add_to_ordered_map(caller: &signer, key: u64) acquires OrderedMapHolder {
        let caller_address = address_of(caller);
        let holder = &mut OrderedMapHolder[caller_address];
        holder.map.add(key, Data{user: caller_address, value:1000})
    }

    public entry fun add_multiple_to_ordered_map(caller: &signer, key: u64, count: u64) acquires OrderedMapHolder {
        while(count > 0) {
            let key = key + count;
            let caller_address = address_of(caller);
            let holder = &mut OrderedMapHolder[caller_address];
            holder.map.add(key, Data{user: caller_address, value:1000});
            count -= 1
        }
    }

    // {
    //   "execution_gas_units": "4",
    //   "io_gas_units": "2",
    //   "storage_fee_octas": "0",
    //   "storage_fee_refund_octas": "0",
    //   "total_charge_gas_units": "5"
    // }
    public entry fun remove_from_ordered_map(caller: &signer, key: u64) acquires OrderedMapHolder {
        let caller_address = address_of(caller);
        let holder = &mut OrderedMapHolder[caller_address];
        if(holder.map.contains(&key)) {
            holder.map.remove(&key);
        }
    }

    public entry fun remove_multiple_from_ordered_map(caller: &signer, key: u64, count: u64) acquires OrderedMapHolder {
        while(count > 0) {
            let key = key + count;
            let caller_address = address_of(caller);
            let holder = &mut OrderedMapHolder[caller_address];
            if(holder.map.contains(&key)) {
                holder.map.remove(&key);
            };
            count -= 1
        }
    }

    // {
    //   "execution_gas_units": "4",
    //   "io_gas_units": "2",
    //   "storage_fee_octas": "43200",
    //   "storage_fee_refund_octas": "0",
    //   "total_charge_gas_units": "437"
    // }
    public entry fun add_to_table(caller: &signer, key: u64) acquires TableHolder {
        let caller_address = address_of(caller);
        let holder = &mut TableHolder[caller_address];
        holder.tab.add(key, Data{user: caller_address, value:1000})
    }

    public entry fun add_multiple_to_table(caller: &signer, key: u64, count: u64) acquires TableHolder {
        while(count > 0) {
            let key = key + count;
            let caller_address = address_of(caller);
            let holder = &mut TableHolder[caller_address];
            holder.tab.add(key, Data{user: caller_address, value:1000});
            count -= 1
        }
    }

    // {
    //   "execution_gas_units": "4",
    //   "io_gas_units": "2",
    //   "storage_fee_octas": "0",
    //   "storage_fee_refund_octas": "43200",
    //   "total_charge_gas_units": "6"
    // }
    public entry fun remove_from_table(caller: &signer, key: u64) acquires TableHolder {
        let caller_address = address_of(caller);
        let holder = &mut TableHolder[caller_address];
        if(holder.tab.contains(key)) {
            holder.tab.remove(key);
        }
    }

    public entry fun remove_multiple_from_table(caller: &signer, key: u64, count: u64) acquires TableHolder {
        while(count > 0) {
            let key = key + count;
            let caller_address = address_of(caller);
            let holder = &mut TableHolder[caller_address];
            if (holder.tab.contains(key)) {
                holder.tab.remove(key);
            };
            count -= 1
        }
    }

    // {
    //   "execution_gas_units": "3",
    //   "io_gas_units": "2",
    //   "storage_fee_octas": "1600",
    //   "storage_fee_refund_octas": "0",
    //   "total_charge_gas_units": "20"
    // }
    public entry fun add_to_vector(caller: &signer,) acquires VectorHolder {
        let caller_address = address_of(caller);
        let holder = &mut VectorHolder[caller_address];
        holder.vec.push_back(Data{user: caller_address, value:1000})
    }

    public entry fun add_multiple_to_vector(caller: &signer, count: u64) acquires VectorHolder {
        while(count > 0) {
            let caller_address = address_of(caller);
            let holder = &mut VectorHolder[caller_address];
            holder.vec.push_back(Data { user: caller_address, value: 1000 });
            count -= 1
        }
    }

    // {
    //   "execution_gas_units": "3",
    //   "io_gas_units": "2",
    //   "storage_fee_octas": "0",
    //   "storage_fee_refund_octas": "0",
    //   "total_charge_gas_units": "4"
    // }
    public entry fun remove_from_vector(caller: &signer) acquires VectorHolder {
        let caller_address = address_of(caller);
        let holder = &mut VectorHolder[caller_address];
        holder.vec.remove(0);
    }

    public entry fun remove_multiple_from_vector(caller: &signer, count: u64) acquires VectorHolder {
        while(count > 0) {
            let caller_address = address_of(caller);
            let holder = &mut VectorHolder[caller_address];
            holder.vec.remove(0);
            count -= 1
            }
    }

}