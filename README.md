RTLQueue
================================
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This is a Godot Plugin which adds a RTLQueue Node.
This Node is similar to, and inspired by [GodotTIE](https://github.com/henriquelalves/GodotTIE).
To elaborate this allows you to queue text which is displayed in a control node. This text can be multicolor / bold / underlined / ..., different sections can have different speeds and more.

## Compatibility

This should be used with a Godot version which is >=3.1 this is because the plugin uses the optional static typing. Although it should be an rather quick fix to remove all the static typing information so it should also work on Godot 3.0. Godot 2.X is untested.

## Features

* Either "paginated" (automatically detects if the next word would break the line) or scrolling text
* Any size works for the Control Element, also resizing should be possible, but the maximal lines won't be recalculated (although you could call the function to do that yourself) and pagination might work unexpected
* You can queue Text, wait times, waiting for user input, clearing the output, images, color override
* Signals for everything you should need (also you can have custom strings emitted when a specific text starts printing or finished, f.e. to change a facial expression when a certain text is printed)
* Full BBCode support (well almost)
* Either append_bbcode mode (more efficient but line break detection might be buggy) or bbcode_text mode (more resource intensive but should be stable)
* Interesting Methods / Properties / Signals are explained below and commented in the code

## Demo

A demo project can be found in the [demo_project](https://github.com/NetroScript/Godot-RTLQueue/tree/demo_project) branch.

## Installation

* Download this Repo
* Move addons/RTLQueue into your project folder
* Enable the addon in Project Settings
* Add the RTLQueue node to your scene

## API / Interesting Properties

### Properties Exposed to the Editor

* Font, Font Mono, Font Bold, Font Italics, Font Bold Italics - Fonts used by the RichTextLabel for the corresponding effects, doesn't need to be set
* Space Between Parts - If you append 2 String "Text." and "Text2." if a space should be used to join those - the space won't be added if it is on a new line
* Enable Scrolling - If Scrolling mode should be used instead of page mode
* Interaction Event - The Input Map event (as String) which is used for all interaction (to continue / speed up)
* Speed Increase - By what factor the speed increases when the interaction key is hold
* Handle Inline BBCode - If set the script will check for opening and closing square brackets to instantly append then instead of revealing 1 char at a time - for it to work the brackets need to be surrounded by spaces (but it can also be multiple BBCode Tags next to each other without a tag)
* Punctuation - There are same cases where you have to leave spaces for the BBCode, but don't actually dont want to have a space there, in this PoolArray you can add the exceptions where the space will be removed. (F.e. "[b] Test [/b] ." - Space between . and Test is unwanted, so it is removed)
* Use Append BBCode - If append_bbcode() is used or bbcode_text+= - more is is said in features, it is best to try out what works for you, considering this is a simple toggle 
* Wait For Input On Finish - If the queue is empty, additionally wait for another interaction input and emit a signal when that input was given

### Signals

* `next_page()` - Emitted when the next page is being displayed
* `queue_finished()` - Emitted when all elements in the queue were processed
* `queue_finished_and_waited()` - Emitted when all elements in the queue were processed, Wait for Input on Finish is set to true and a interaction key was pressed
* `event(event)` - Emitted when a text has a custom event and the first letter is written. `event` is the string supplied by the user.
* `event_end(event)` - Emitted when a text has a custom event and the last letter is written. `event` is the string supplied by the user.
* `page_full()` - Emitted when the page is full (and the script is being paused because it is full) - only emitted in paginated mode
* `queue_event(type)` - Emitted when a queue event was processed, currently the only event is changing the "global" color. `type` is the type of queue event. (currently only `colorchange`)
* `queue_wait_start()` - Emitted when a wait (silence) begins
* `queue_wait_end()` - Emitted when a wait (silence) ends
* `bbcode_cleared()` - Emitted when in the queue the current text gets cleared (not when page is turned)
* `paused_until_input()` - Emitted when it is waiting for user input (through the queue item)
* `awaiting_input(type)` - Generally when awaiting user input (so you don't have to listen for every signal when input is needed) - Following types currently:
  * `paused_until_input`
  * `queue_finished` - Only emitted when Wait For Input On Finish is set to true
  * `page_full`
* `got_input(type)` - When the needed input was supplied - Following types:
  * `changed_page`
  * `finished_wait_for_input`
  * `finished_wait_for_queueend` - Only emitted when Wait For Input On Finish is set to true
* `pause()` - Emitted when an item in the queue paused the queue
  
### Methods you can use

* `init()` - if you change any settings in code (like the current font or the line separation) you can call this method so the script updates itself, this can break pagination
* `clear(extendedclear : bool = false)` - Forcefully clear the current text, if the optional value is set to true, `done_queue` and `previous_pages` and other variables will be reset
* `get_max_lines()` - recalculate maximal lines (should not be called, unless you have a project where resizing the text box works (because previous pages will still be the same size, new pages will be the new size))

Following functions all append to the queue, so that the result will show when the previous queue was processed

* `add_text(text : String, characterpersecond : float, event : String = "", options : PoolIntArray = PoolIntArray(), color : Color = Color(0,1,0,0))` - event (gets emitted once at start, once as end event when the text finished), options (can be multiple) and color (the color with the default values in the function declaration gets ignored) are optional, options can contain the OPTIONS_* enum values:
  * `OPTIONS_BOLD` - Makes text bold
  * `OPTIONS_ITALICS` - Makes text italic
  * `OPTIONS_UNDERLINED` - Makes text underlined
  * `OPTIONS_STRIKETHROUGH` - Makes text strikethrough
  * `OPTIONS_CODE` - Text will be enclosed in code tags
  * `OPTIONS_RIGHT` - Text will be enclosed in right tags
  * `OPTIONS_FILL` - Text will be enclosed in fill tags
  * `OPTIONS_CENTER` - Text will be enclosed in center tags
  * `OPTIONS_IGNOREBBCODE` - Contained [<tag>] will not be parsed
* `add_wait(time : float)` - Wait for n seconds
* `add_wait_for_interaction()` - Pause until the interaction key is pressed
* `add_clear()` - Clear the current text
* `add_image(imagepath : String, time : float = 0)` - imagepath should be a string with the "res://" path to the image, there is an optional wait until the image is added in seconds
* `add_newline(amount : int = 1)` - Add a newline (you can also supply an integer to add more than 1 newline)
* `add_pause()` - Pause the execution, the attribute paused has to manually be set to false again
* `set_color(color : Color)` - If they don't have a text color all following strings will have that color

### Attributes which might be interesting

* `paused` - Is set to true when the queue finishes, decides whether the queue is processed
* `previous_pages` - If enabled, contains the previous pages in an array (Array of Arrays)
* `bbcodebuffer` - If append mode is enabled, this will contain all the raw bbcode_text, because append doesn't update it
* `current_queue` - Items which are currently being processed, if you want to clear the Queue, you can set this to an empty Array

## Differences to GodotTIE

* It is a RichTextLabel instead of a Label, allowing the usage of BBCode
* Functions which do the same thing have a different name (f.e. add_text instead off buff_text)
* There is no input mode
* There are less settings, although this also includes everything I need for my usage
* For more difference take a look at available attributes and methods

## Changelog

Check it [here](https://github.com/NetroScript/Godot-RTLQueue/blob/master/CHANGELOG.md).
