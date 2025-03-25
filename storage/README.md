Here is the reference cost to store data with multiple data structures in Aptos.

The data stored in these data structures are,
```
    struct Data has key, store, drop {
        user: address,
        value: u64,
    }
```



| Data Structure  | Storage Cost to Create | Storage Cost To Add One | Storage Rebate on Removal | Storage Rebate on Deletion |
|-----------------|------------------------|-------------------------|---------------------------|----------------------------|
| OrderedMap      | 44,040                 | 1,920                   | 0                         | 44,040                     |
| BigOrderedMap   | 46,680                 | 1,960                   | 0                         | 46,680                     |
| TableWithLength | 43,840                 | 43,200                  | 43,200                    | 45,360                     |
| Vector          | 43,840                 | 1,600                   | 0                         | 43,840                     |
| Object          | 93,760                 | N/A                     | N/A                       | 93,760                     |

While inserting and deleting 100 elements
| Data Structure  | Storage Cost to Create | Storage Cost To Add 100 | Storage Rebate on Remove 100 | Storage Rebate on Deletion |
|-----------------|------------------------|-------------------------|------------------------------|----------------------------|
| OrderedMap      | 44,040                 | 192,000                 | 0                            | 236,040                    |
| BigOrderedMap   | 46,680                 | 283,840                 | 280,880                      | 49,640                     |
| TableWithLength | 43,840                 | 4,320,000               | 4,320,000                    | 45,360                     |
| Vector          | 43,840                 | 160,000                 | 0                            | 203,840                    |



Takeaways: 
1. You can only delete table with length, you can not delete table.move(and no storage rebate for deleting)
2. Only on tables we can get storage rebate while removing items.
3. Tables cost the most to insert data because each data in stored in a separate storage slot. But all the storage cost will be returned to those who remove the table entries.
4. Vectors and ordered_maps cost very less to insert compared to tables because they're not stored in a different storage slot and cost increase needs to be tested as this test only consisted of creation, an insertion,a removal and deletion.
