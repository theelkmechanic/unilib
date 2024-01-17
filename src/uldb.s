.include "unilib_impl.inc"

.code

uldb_fromBRP:        ; r0 = BRP, r1 = size; returns data block handle in YX, takes ownership of the passed BRP (will free it when reference count drops to 0)
uldb_fromBuffer:     ; r0 = pointer to memory, r1 = size to copy; returns data block handle in YX, allocates new data BRP and copies from pointer
uldb_fromIter:       ; r0 = iterator, r1 = size; returns data block handle in YX, allocates new data BRP and copies r1 entries from iterator
uldb_getrefcount:    ; YX = data block handle; returns reference count in YX
uldb_addref:         ; YX = data block handle; increments reference count
uldb_release:        ; YX = data block handle; decrements reference count, frees data block BRP and data BRP when it hits zero
uldb_getsize:        ; YX = data block handle; returns size of data in YX
uldb_getcapacity:    ; YX = data block handle; returns capacity of data BRP in YX
uldb_getbrp:         ; YX = data block handle; returns data BRP in YX
    rts
