# Windowing (ulwin_*)

UniLib provides a full windowing system supporting up to 64 overlapping windows with Unicode text, automatic occlusion tracking, and double-buffered screen updates via the VERA.

## Concepts

### Windows

Each window has:
- A position and size on the 80x60 character screen
- An optional border (drawn automatically)
- Independent character and color buffers in banked RAM
- A cursor position for text output
- Foreground and background colors
- A title string (displayed in the border)

Windows are managed as a linked list ordered front-to-back. The topmost window is the "current" window. Window 0 is always the full-screen background.

### Window Handles

Windows are identified by handles (0-63) returned from `ulwin_open`. Handle 0 is the screen window created by `ul_init`. Most window functions take the handle in the A register.

### Screen Refresh

Changes to window contents are buffered. Call `ulwin_refresh` to composite all visible windows onto the screen. The system tracks dirty regions to minimize VERA writes.

## Window Lifecycle

### ulwin_open

Open a new window.

```
Input:  r0L   = start column of content area
        r0H   = start line of content area
        r1L   = number of columns (width)
        r1H   = number of lines (height)
        r2L   = foreground color (ULCOLOR)
        r2H   = background color (ULCOLOR)
        r3    = title string pointer (0 for no title)
        r4H   = flags:
                  $80 = ULWIN_FLAGS::BORDER (draw a border around the window)
Output: A     = window handle (0 = failure)
```

The window must fit entirely on screen (including its border if BORDER flag is set). The new window becomes the current (topmost) window. Allocates character and color buffers in banked RAM.

### ulwin_close

Close a window and free its resources.

```
Input:  A     = window handle
```

Frees character and color buffers. Does not close child windows if the window was split.

### ulwin_select

Bring a window to the top of the window stack.

```
Input:  A     = window handle
```

Makes the specified window the current (topmost) window and updates occlusion state for all windows.

## Cursor and Position

### ulwin_putcursor

Set the cursor position within a window.

```
Input:  A     = window handle
        X     = column (0-based, relative to content area)
        Y     = line (0-based, relative to content area)
```

### ulwin_getcursor

Get the current cursor position.

```
Input:  A     = window handle
Output: X     = column
        Y     = line
```

### ulwin_getcolumn / ulwin_getline

Get just the cursor column or line.

```
Input:  A     = window handle
Output: A     = column or line
```

### ulwin_getpos

Get the screen position of a window's content area.

```
Input:  A     = window handle
Output: X     = start column
        Y     = start line
```

### ulwin_getsize

Get the size of a window's content area.

```
Input:  A     = window handle
Output: X     = number of columns
        Y     = number of lines
```

## Text Output

### ulwin_putchar

Write a single Unicode character at the cursor position.

```
Input:  A     = window handle
        r0/r1L = Unicode codepoint (r0L = low byte, r0H = mid byte, r1L = high byte)
```

The cursor advances by one position after writing a printable character.

### ulwin_putstr

Write a string at the current cursor position.

```
Input:  A     = window handle
        r0    = string BRP
        carry = set to enable autowrap and scrolling
```

With carry clear, text that exceeds the line width is clipped. With carry set, text wraps to the next line and the window scrolls when the last line is reached.

### ulwin_putloc

Write a string at a specific position.

```
Input:  A     = window handle
        r0    = string BRP
        X     = column
        Y     = line
        carry = set to enable autowrap and scrolling
```

Moves the cursor to (X, Y) then writes the string. The cursor position is updated.

### ulwin_putcolor

Set the colors for future text output.

```
Input:  A     = window handle
        X     = foreground color (ULCOLOR)
        Y     = background color (ULCOLOR)
        carry = set to update the entire window immediately
```

With carry clear, only future output uses the new colors. With carry set, all existing content in the window is recolored.

### ulwin_puttitle

Update a window's title.

```
Input:  A     = window handle
        r0    = title string BRP
```

## Text Input and Reading

### ulwin_getchar

Read the character at the cursor position.

```
Input:  A     = window handle
Output: AYX   = Unicode codepoint
```

### ulwin_getstr

Get the remainder of the current line as a string.

```
Input:  A     = window handle
Output: YX    = string BRP (from cursor to end of line)
```

### ulwin_getloc

Get the remainder of a line at a specific position.

```
Input:  A     = window handle
        X     = column
        Y     = line
Output: YX    = string BRP
```

### ulwin_getcolor

Get the current output colors.

```
Input:  A     = window handle
Output: X     = foreground color
        Y     = background color
```

### ulwin_getwin

Get the current (topmost) window handle.

```
Output: A     = current window handle
```

## Keyboard Input

### ulwin_getkey

Wait for and return a keystroke, translated to Unicode.

```
Output: AYX   = Unicode codepoint of pressed key
```

If an idle function is configured (see `ulwin_idlecfg`), it is called repeatedly while waiting.

### ulwin_gethit

Non-blocking check for a pending keystroke.

```
Output: carry = set if a key is available
```

### ulwin_idlecfg

Configure a function to call while waiting for keyboard input.

```
Input:  YX    = address of idle function (0 to disable)
```

The idle function is called in a loop by `ulwin_getkey` between checking for input.

## Editing Operations

### ulwin_inschar

Insert a character at the cursor, shifting the rest of the line right.

```
Input:  A     = window handle
        r0/r1L = Unicode codepoint
```

### ulwin_delchar

Delete the character at the cursor, shifting the rest of the line left.

```
Input:  A     = window handle
```

### ulwin_insline

Insert a blank line at the cursor, shifting lines below down.

```
Input:  A     = window handle
```

### ulwin_delline

Delete the line at the cursor, shifting lines below up.

```
Input:  A     = window handle
```

### ulwin_eraseeol

Erase from the cursor to the end of the line.

```
Input:  A     = window handle
```

## Scrolling

### ulwin_scroll

Scroll the window contents.

```
Input:  A     = window handle
        X     = columns to scroll (signed: positive = right, negative = left)
        Y     = lines to scroll (signed: positive = down, negative = up)
```

**Note on direction**: Y = -1 (`$FF`) scrolls content UP (new blank line appears at bottom), which is the typical behavior when adding text at the bottom. Y = 1 scrolls content DOWN.

## Window Layout

### ulwin_move

Move a window to a new screen position.

```
Input:  A     = window handle
        X     = new start column of content area
        Y     = new start line of content area
Output: carry = set on success
```

The window (including border) must fit entirely on screen at the new position.

### ulwin_resize

Resize a window.

```
Input:  A     = window handle
        X     = new content width
        Y     = new content height
Output: carry = set on success
```

### ulwin_splitline

Split a window horizontally at a line.

```
Input:  A     = window handle
        Y     = split line (0-based)
Output: A     = new window handle (bottom portion)
        carry = set on success
```

The original window keeps lines 0 through split-1. A new window is created for lines split through end. The new window is selected and returned.

### ulwin_splitcolumn

Split a window vertically at a column.

```
Input:  A     = window handle
        X     = split column (0-based)
Output: A     = new window handle (right portion)
        carry = set on success
```

### ulwin_joinlines

Join two windows vertically (first on top, second on bottom).

```
Input:  X     = first window handle (becomes top)
        Y     = second window handle (becomes bottom)
Output: A     = joined window handle
        carry = set on success
```

Windows must be the same width and the combined height must fit on screen.

### ulwin_joincolumns

Join two windows horizontally (first on left, second on right).

```
Input:  X     = first window handle (becomes left)
        Y     = second window handle (becomes right)
Output: A     = joined window handle
        carry = set on success
```

Windows must be the same height.

## Drawing

### ulwin_box

Draw a box inside a window using line-drawing characters.

```
Input:  A     = window handle
        r0    = top-left corner (r0L = column, r0H = line)
        r1    = bottom-right corner (r1L = column, r1H = line)
```

### ulwin_clear

Clear a window's contents (fills with spaces in the current color).

```
Input:  A     = window handle
```

## Screen Refresh

### ulwin_refresh

Composite all visible windows and update the screen.

```
Input:  (none)
```

Only the dirty (changed) regions are updated for performance. Call this after making changes to window contents.

### ulwin_force

Force a complete refresh on the next `ulwin_refresh` call.

```
Input:  (none)
```

Marks the entire screen as dirty, ensuring every pixel is redrawn.

## Dialogs and Messages

### ulwin_error

Display a modal error dialog.

```
Input:  r0    = error message string BRP
```

Shows a centered popup with the error message. Waits for a keypress before dismissing.

### ulwin_errorcfg

Configure error dialog colors.

```
Input:  X     = foreground color
        Y     = background color
```

### ulwin_flash

Display a flash message overlay.

```
Input:  r0    = message string BRP
        r1    = title string BRP
        X     = foreground color
        Y     = background color
```

### ulwin_flashwait

Display a flash message and wait.

```
Input:  r0    = message string BRP
        r1    = title string BRP
        X     = foreground color
        Y     = background color
        A     = seconds to wait
```

### ulwin_busy

Display a "Busy" indicator.

```
Input:  YX    = custom busy string BRP (0 = default "Busy...")
```

### ulwin_picklist

Display a scrollable selection list.

```
Input:  A     = window handle
        YX    = string table BRP containing choices
Output: A     = selected choice index (1-based), 0 if cancelled
```

Shows the string table entries as a scrollable list within the specified window. The user navigates with arrow keys and selects with ENTER.
