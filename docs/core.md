# Core Functions

## ul_init

Initialize UniLib. Must be called before any other UniLib function.

```
Input:  r0    = pointer to font filename (e.g., "unilib.ulf")
        r1L   = font filename length
        r1H   = drive number to load font from (typically 8)
        r2L   = screen foreground color (ULCOLOR enum)
        r2H   = screen background color (ULCOLOR enum)
Output: A     = error code (ULERR::OK on success)
```

Initializes the banked RAM memory manager, loads the font file, sets up the VERA palette, and creates the full-screen background window (handle 0).

## ul_geterror

Retrieve the last error code set by a UniLib function.

```
Input:  (none)
Output: A     = last error code (ULERR enum)
```

## ul_isprint

Check if a Unicode character is printable (i.e., `ulwin_putchar` would advance the cursor for it).

```
Input:  AYX   = Unicode codepoint (A = high byte, Y = mid, X = low)
Output: carry = set if printable
```

## Error Codes (ULERR)

| Value | Name | Description |
|-------|------|-------------|
| 0 | `OK` | Success |
| 1 | `INVALID_PARAMS` | One or more parameters are out of range or invalid |
| 2 | `INVALID_HANDLE` | Window or object handle is not valid |
| 3 | `INVALID_BRP` | Banked RAM pointer is not valid (wrong bank, slot, or corrupt) |
| 4 | `OUT_OF_MEMORY` | Not enough banked RAM to fulfill allocation |
| 5 | `OUT_OF_RESOURCES` | System limit reached (e.g., max 64 windows) |
| 6 | `STRING_TOO_LONG` | String exceeds maximum supported length |
| 7 | `INVALID_UTF8` | Input contains invalid UTF-8 byte sequences |
| 8 | `LOAD_FAILED` | File load operation failed |

## Color Palette (ULCOLOR)

UniLib defines its own 15-color palette (values 1-15):

| Value | Name |
|-------|------|
| 1 | `BLACK` |
| 2 | `DGREY` |
| 3 | `MGREY` |
| 4 | `LGREY` |
| 5 | `WHITE` |
| 6 | `RED` |
| 7 | `BROWN` |
| 8 | `GREEN` |
| 9 | `CYAN` |
| 10 | `BLUE` |
| 11 | `MAGENTA` |
| 12 | `LIGHTRED` |
| 13 | `YELLOW` |
| 14 | `LIGHTGREEN` |
| 15 | `LIGHTBLUE` |

These are used with windowing functions for foreground and background colors. They do not correspond to the standard PETSCII/VIC color numbers.
