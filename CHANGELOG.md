1.1
===

Improved:
 * Declare class name, so when using static typing you have autocompletion
 * Formatting
 * Changed italic to italics
 * In clear() also add possibility to clear previous pages
 * Allow to show more than 1 character by frame (now up to 1 entire queue per frame)
 * Add a Queueoptions class to handle all the options instead of a Dictionary
    * Color and Event are now passed to add_text() as a parameter each, Options are passed in a PoolIntArray which contains entries from the enum containing OPTIONS_*
	* Now the script has more "secure" lines and might be more optimized by the Engine in a later Godot update
    * Queueoptions properties are now entire words instead of single letters
 

1.0
===

Initial Release