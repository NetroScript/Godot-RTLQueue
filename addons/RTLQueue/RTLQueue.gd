# Made by NetroScript, this plugin is usable under the MIT License
# For more information please visit Github: https://github.com/NetroScript/Godot-RTLQueue

extends ReferenceRect

# The Fonts should have the same heights
export var FONT : Font
export var FONT_MONO : Font
export var FONT_BOLD : Font
export var FONT_ITALIC : Font
export var FONT_BOLD_ITALIC : Font

# Currently not used for anything, but you can add custom behaviour like being able to view the previous page yourself
export onready var KEEP_PREVIOUS_QUEUE : bool = true

# How much space between lines
export onready var LINE_SEPARATION : int = 2

# If single pushed Strings should have a space between them. 
export var SPACE_BETWEEN_PARTS : bool = true

# If the Scrolling feature of GODOT should be used
export var ENABLE_SCROLLING : bool = false

# Input event name which triggers code speed up + showing the next "page" + ending the input
export var INTERACTION_EVENT : String = "player_jump"

# When holding the interaction key, how much the text / pause should be sped up
export var SPEED_INCREASE : float = 3

# If there is inline BBCode handle it correctly in append mode and bbcode_text mode
# If you want to use inline BBCode always have it surounded by spaces(those will be ignored later) f.e. add_text("[b] Fat text [/b]", 1) so it isn't clutched together with the word
export var HANDLE_INLINE_BBCODE : bool = true

# Characters (/words) where we don't wan't to add a space when stripping BBCode
export var PUNCTUATION : PoolStringArray = PoolStringArray([",", ";", ".", "!", "?"])

# Use append_bbcode instead of bbcode_text +=
# It then increases the amount of visible characters and adds every String directly
# Following Advantages: More efficient, Inline BBCODE possible
# Disadvantages: Unexpected Behaviour (especially considering line-break detection), breaks on resize (Although the script already adds the previous Content on resize again), if you add a tag previously (f.e. center) it will not count for further added Strings
export var USE_APPEND_BBCODE : bool = true


onready var max_lines : int = 0
onready var label : RichTextLabel = RichTextLabel.new()
onready var previous_pages : Array = Array()
onready var done_queue : Array = Array()
onready var current_queue : Array = Array()
# Possible Queue types
enum {NORMAL_TEXT, IMAGE, OPERATOR, WAIT, CLEAR, WAIT_INPUT, NEW_LINE}
# Used for time related stuff, to decide whether to do an action or not
var counter : float = 0
# If the Skript should be paused
var paused : bool = false
# used to decide if it is the start of a wait sequence
var queue_start : bool = true
# The "global" color which is the default color when an Queueitem doesn't have a color property
var last_active_color : Color = Color(1,1,1,1)
var waiting_for_next_page : bool = false
var check_newline : bool = false
# Currentvisible Lines only counts lines from autowrap, so we have to count newline characters (+ some tags which break the line) seperately
var current_newlines : int = 0
# Modify the current speed
var speed_up : float = 1
# Variable to keep track of if in the current step the number of lines increased
var last_lines : int = 1
# Variable to decide whether to prepend (and append) all the tags which are cut mid sentence
var tag_active : bool = true
# Variable to keep track of the current BBCode when using the appending mode
var bbcodebuffer : String = ""
# If a new string starts on a newline, don't prepend a space
var on_newline : bool = true
# When waiting for input
var waiting_for_input : bool = false
# List of those closing tags where we need to remove preceding whitespace
# Theoretically this also needs to be used for pure url, but because [url=] would break then, it is not included, if it is wanted feature I could image a add_url() function
const SPECIAL_TAGS : PoolStringArray = PoolStringArray(["[/img]"])

# Signals

signal next_page() # When the next page starts to be displayed
signal queue_finished() # When the to do queue is empty
signal event(event) # When a text has a custom event and it starts to be written
signal event_end(event) # When the text of a specific event finished writing
signal page_full() # When the script waits for the input event until continuing
signal queue_event(type) # When a specific Operator is used, currently only set color, pause
signal queue_wait_start() # When a wait (silence) starts
signal queue_wait_end() # When a wait (silence) ends
signal bbcode_cleared() # When the screen gets cleared
signal paused_until_input() # When an input Wait has been issued (like a page turn)
signal awaiting_input(type) # Everytime sent when an user interaction is sent, also when queue ended (waiting for close interaction f.e.), following 3 types: page_full, queue_finished, paused_until_input
signal got_input(type) # When Input was supplied, following 2 types: changed_page, finished_wait_for_input
signal pause() # When an operator in the queue paused it

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_physics_process(true)
	set_process_input(true)
	add_child(label)
	
	# For the appending mode, register the resize event, so the text can be added again
#warning-ignore:return_value_discarded
	get_tree().get_root().connect("size_changed", self, "_on_resize")
	
	# Initialize Variable stuff
	# You can call this again later when changing exportet settings in code
	init()
	

func init() -> void:
	# Setting font of the text
	if FONT != null:
		label.add_font_override("font", FONT)
		label.set("custom_fonts/normal_font", FONT)
	else:
		FONT = label.get_font("")
	if FONT_BOLD != null:
		label.set("custom_fonts/bold_font", FONT_BOLD)
	if FONT_ITALIC != null:
		label.set("custom_fonts/italics_font", FONT_ITALIC)
	if FONT_BOLD_ITALIC != null:
		label.set("custom_fonts/bold_italics_font", FONT_BOLD_ITALIC)
	if FONT_MONO != null:
		label.set("custom_fonts/mono_font", FONT_MONO)
	
	# Set further attributes which are needed
	label.bbcode_enabled = true
	label.anchor_bottom = 1.0
	label.anchor_right = 1.0
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.margin_bottom = 0
	label.margin_left = 0
	label.margin_right = 0
	label.margin_top = 0
	
	# If scrolling is not enabled, we disable the scrollbar
	if not ENABLE_SCROLLING:
		label.scroll_active = false
		label.scroll_following = false
	else:
		label.scroll_active = true
		label.scroll_following = true
	
	# Get the maximum number of lines in the current container
	get_max_lines()

	# Set the line seperation
	label.set("custom_constants/line_separation", LINE_SEPARATION)
	
	# If we use the appending mode, we set visible characters to zero
	if USE_APPEND_BBCODE:
		label.visible_characters = 0
	else:
		label.visible_characters = -1

# Clear the current code, set newlines to zero and reset the text depending on mode
func clear() -> void:
	current_newlines = 0
	on_newline = true
	if USE_APPEND_BBCODE:
		label.visible_characters = 0
	else:
		label.visible_characters = -1
		label.bbcode_text = ""
	bbcodebuffer = ""
	label.clear()


func _input(event : InputEvent) -> void:
	# When our interaction event is clicked and we are waiting for the next page, we will go to the next page
	if event.is_action_pressed(INTERACTION_EVENT):
		if waiting_for_next_page:
			next_page()
			emit_signal("got_input", "changed_page")
		# When wait event continue with the data
		if waiting_for_input:
			waiting_for_input = false
			emit_signal("got_input", "finished_wait_for_input")

func next_page() -> void:
	# Store current page in an object
	if KEEP_PREVIOUS_QUEUE:
		previous_pages.append(done_queue)
		# We make a copy instead of passing the reference
		previous_pages[previous_pages.size()-1].append(JSON.parse(JSON.print(current_queue[0])))
	# Empty the queue
	done_queue = Array()
	waiting_for_next_page = false
	if not ENABLE_SCROLLING:
		tag_active = true
		clear()
	else:
		# When scrolling is enabled we have to fake turning the next page
		current_newlines -= max_lines 
	emit_signal("next_page")

func get_max_lines() -> int:
	# Wait for the object to render correclty
	yield(get_tree(), "idle_frame")
	max_lines = int(floor(get_size().y / ( FONT.get_height() + LINE_SEPARATION)))
	return max_lines


func _physics_process(delta : float) -> void:

	# If our interaction key is pressed we increase our speed variable
	if Input.is_action_pressed(INTERACTION_EVENT):
		if not waiting_for_next_page:
			speed_up = SPEED_INCREASE
	else:
		speed_up = 1

	
	if not paused and not waiting_for_next_page and not waiting_for_input:
		if current_queue.size() == 0:
			emit_signal("queue_finished")
			emit_signal("awaiting_input", "queue_finished")
			paused = true
		else:
			var currentitem : Dictionary = current_queue[0]
			match currentitem["type"]:
				NORMAL_TEXT:
					# Increase the speed by speed_up
					counter+=delta*speed_up
					
					# used to decide if all words are written
					var finished : bool = false

					# This is only -1 on the first initialisation so we do our setup stuff here
					if currentitem["cw"] == -1:
						
						# Add a new space if enabled
						if SPACE_BETWEEN_PARTS and not on_newline:
							_append_text(" ")
							# In append mode we also have to show that
							if USE_APPEND_BBCODE:
								label.visible_characters+=1
						
						# Reset newline because now a word will be written
						on_newline = false
						
						# Add the spaces again which were lost while splitting the string
						var i : int = 1
						for word in currentitem["wl"]:
							# If the word is not the last, or doesn't seems to be BBCode add a space to recreate the original string 
							if not (HANDLE_INLINE_BBCODE and word.length() > 0 and word[0]=="[" and not (currentitem.has("ignorebb") and currentitem["ignorebb"]) and word[word.length()-1] == "]"):
								if i != currentitem["wl"].size():
									currentitem["wl"][i-1] += " "
							# If we "strip" tags and punctiation is following, we don't want to add a space
							else:
								if i-2 > 0 and currentitem["wl"].size() >= i and (currentitem["wl"][i] in PUNCTUATION) and currentitem["wl"][i-2][ currentitem["wl"][i-2].length()-1] == " ":
									currentitem["wl"][i-2] = currentitem["wl"][i-2].left(currentitem["wl"][i-2].length()-1)
								elif i-2 > 0 and word in SPECIAL_TAGS:
									currentitem["wl"][i-2] = currentitem["wl"][i-2].left(currentitem["wl"][i-2].length()-1)
							
							i+=1
						
						# It is the start of the query, so in any case the tags like color or bold need to be appended
						tag_active = true
						
						# If a custom event is set, we emit a signal
						if currentitem["e"] != "":
							emit_signal("event", currentitem["e"])
						
						# Set the current word which is shown to the first one
						currentitem["cw"] = 0

					# If a new query or a new page we need to write all tags
					if tag_active:
						
						# Tag text, all in 1 string, so we do less changes (so it needs to be parsed less often)
						var outtext : String = ""
						
						# If there is a custom color, use it, otherwise use the "global" color
						if "c" in currentitem:
							outtext += "[color=#"+currentitem["c"].to_html()+"]"
						else:
							outtext += "[color=#"+last_active_color.to_html()+"]"
							
						# Variables to store all flags like bold / centered
						var flags : String = ""
						var endingflags : String = ""
						for flag in currentitem["flags"]:
							flags += "["+flag+"]"
							endingflags = "[/"+flag+"]"+endingflags
							
							# The following tags will break into a newline (if not at the start of the RTL) so we add to newlines
							if flag == "fill" or flag == "right" or flag == "center" or flag == "code":
								current_newlines += 1

						# If we are in append mode we already add the entire query string with the opening and closing tags, otherwise we just add the opening tags
						if USE_APPEND_BBCODE:
							outtext += flags
							
							var i : int = currentitem["cw"]
							while i < currentitem["wl"].size():
								outtext += currentitem["wl"][i]
								i+=1
							
							outtext += endingflags
							_append_text(outtext)
						else:
							_append_text(outtext+flags)
							
						# Tags have been added
						tag_active = false

					# If the current word exists do all the word handling code
					if currentitem["wl"].size() > currentitem["cw"]:
						
						# Current word
						var word : String = currentitem["wl"][currentitem["cw"]]
						
						# Might be obsolente because space is added
						if word == "":
							currentitem["cw"]+=1
							if currentitem["wl"].size() <= currentitem["cw"]:
								finished = true
						elif HANDLE_INLINE_BBCODE and word[0]=="[" and not (currentitem.has("ignorebb") and currentitem["ignorebb"]) and word[word.length()-1] == "]":
							
							if word=="[img]":
								if not USE_APPEND_BBCODE:
									_append_text(word)
									if currentitem["wl"].size() > currentitem["cw"] + 2:
										_append_text(currentitem["wl"][currentitem["cw"] + 1]+currentitem["wl"][currentitem["cw"] + 2])
									
								currentitem["cw"]+=3
								
							else:
							
								if not USE_APPEND_BBCODE:
									_append_text(word)
									
								currentitem["cw"]+=1
						else: 
							# If the current word is new, we check if the line breaks if we add the current word
							if check_newline:
								
								#print("Maximal Lines: " + str(max_lines) + " | Current Lines: " + str(label.get_visible_line_count() + current_newlines))
								# Only do the checking if the current line is already the max lines (because a change from f.e. line 1 to 2 with 3 max lines doesn't matter)
								if(label.get_visible_line_count() + current_newlines >= max_lines):
									# If Using Append mode just make all characters visible, otherwise add the word to the BBCode
									if USE_APPEND_BBCODE:
										label.visible_characters += word.length()
									else: 
										_append_text(word)
									# Wait for it to render correctly
									yield(get_tree(), "idle_frame")
									#print("New Max Lines: " + str(label.get_visible_line_count() + current_newlines))
									# If it now exceeds the maximal lines
									if(label.get_visible_line_count() + current_newlines > max_lines):
										# Fake Page not being full by decreasing current newlines
										if ENABLE_SCROLLING:
											current_newlines -= 1
										# Emit page full signal and wait for the next page
										else:
											waiting_for_next_page = true
											emit_signal("awaiting_input", "page_full")
											emit_signal("page_full")
											#print("We have to open the next page")
									# After the check eighter reduce visible characters again or remove the word from the box
									if USE_APPEND_BBCODE:
										label.visible_characters -= word.length()
									else:
										label.bbcode_text = label.get_bbcode().left(label.get_bbcode().length()-word.length())
									check_newline = false
								else:
									check_newline = false

							# If the current word wouldn't break the line to a new page
							if not waiting_for_next_page:
								# If enough time passed to display the character
								if(counter > 1/currentitem["t"]):
									# Remove the time for one character, in the case of lag the counter doesn't need to count up again, but would do 1 char on each tick
									counter -= 1/currentitem["t"]

									# Keep track if the line number increased, if so set newline to true
									# This might not be needed at all because on_newline is set in add_newline and chance of a query string ending perfectly on a line is really low
									if label.get_visible_line_count() + current_newlines > last_lines:
										last_lines = label.get_visible_line_count()  + current_newlines
										on_newline = true
									else:
										on_newline = false

									# If in append mode increase the currently shown characters, otherwise add it to the bbcode text
									if USE_APPEND_BBCODE:
										label.visible_characters += 1
									else:
										_append_text(word[currentitem["ci"]])
									
									# Increase the character of the current word
									currentitem["ci"]+=1
									# If current characters index is longer than the word switch to character index 0 on the next word an enable checking for newline again
									if currentitem["ci"] >= word.length():
										currentitem["ci"] = 0
										currentitem["cw"]+=1
										check_newline = true

					# If this word was the last word in the list, set finished to true
					if currentitem["wl"].size() <= currentitem["cw"]:
						finished = true

					# Considering I have no idea if it is passed by reference or copy, we set the current_queue item to the modiefied currentitem
					current_queue[0] = currentitem
					
					# Code when the current text was finished
					if finished:
						# If a custom event is set, we emit an end signal
						if currentitem["e"] != "":
							emit_signal("event_end", currentitem["e"])
						
						# If we do not use the append mode, we now have to close all our tags
						if not USE_APPEND_BBCODE:
							currentitem["flags"].invert()
							var closingflags : String = ""
							for flag in currentitem["flags"]:
								closingflags += "[/"+flag+"]"
							currentitem["flags"].invert()
							_append_text(closingflags+"[/color]")
						# Reset our counter
						counter = 0
						
						# Removing the task from the working queue
						done_queue.append(current_queue.pop_front())

				OPERATOR:
					# If we change the color, set the current active color to the new one
					if currentitem["e"] == "colorchange":
						last_active_color = currentitem["data"]
					# If it is a pause, pause the execution
					elif currentitem["e"] == "pause":
						paused = true
						emit_signal("pause")
						
					# Emit the signal of the operator
					emit_signal("queue_event", currentitem["e"])
					# Removing the task from the working queue
					done_queue.append(current_queue.pop_front())

				NEW_LINE:
					# Append a newline in the current text
					_append_text("\n")
					# Increase our amount of newlines
					current_newlines+=1
					# Removing the task from the working queue
					done_queue.append(current_queue.pop_front())
					on_newline = true

				WAIT:
					counter+=delta*speed_up
					# If this is called for the first time emit wait start
					if queue_start:
						queue_start = false
						emit_signal("queue_wait_start")
					# If the wait time is over emit wait end and move on to the next task
					if counter > currentitem["t"]:
						queue_start = true
						emit_signal("queue_wait_end")
						counter = 0
						# Removing the task from the working queue
						done_queue.append(current_queue.pop_front())

				CLEAR:
					clear()
					emit_signal("bbcode_cleared")
					# Removing the task from the working queue
					done_queue.append(current_queue.pop_front())

				WAIT_INPUT:
					waiting_for_input = true
					emit_signal("paused_until_input")
					emit_signal("awaiting_input", "paused_until_input")
					# Removing the task from the working queue
					done_queue.append(current_queue.pop_front())

				IMAGE:
					counter+=delta*speed_up
					if counter > currentitem["t"]:
						
						# Add the image to the text box
						_append_text(currentitem["path"])
						# If it is Append Mode we have to increase the shown characters
						if USE_APPEND_BBCODE:
							label.visible_characters += 1
						
						# If this would be more than the maximal lines on line break 
						if(last_lines >= max_lines):
							# Wait for it to render correctly
							yield(get_tree(), "idle_frame")
							# If more than maximal lines wait for the next page, remove the added image (or make it invisible) and prevent removing this image from the pending queue
							if label.get_visible_line_count() + current_newlines > last_lines:
								waiting_for_next_page = true
								print("Image would break line")
								if USE_APPEND_BBCODE:
									label.visible_characters -= 1
								else:
									label.bbcode_text = label.get_bbcode().left(label.get_bbcode().length()-currentitem["path"].length())
								return
						
							
						counter = 0
						# Removing the task from the working queue
						done_queue.append(current_queue.pop_front())

# Add text to the RichTextLabel
# Needs a text string and how many characters per second should be displayed
# Optionally a dictionary can be supplied which can have the options in the settings variable
func add_text(text : String, characterpersecond : float, options : Dictionary = {}) -> void:

	# Remove a newline character, otherwise it wouldn't be kept track of and the code for pages would break
	text = text.replacen("\n", "")

	# Possible options and their default value
	var settings : Dictionary = {
		"color": options["color"] if options.has("color") else Color(0,1,0,0),
		"event": options["event"] if options.has("event") else "",
		"bold" : options["bold"] if options.has("bold") else false,
		"italic" : options["italic"] if options.has("italic") else false,
		"underlined" : options["underlined"] if options.has("underlined") else false,
		"strikethrough" : options["strikethrough"] if options.has("strikethrough") else false,
		"code" : options["code"] if options.has("code") else false,
		"right" : options["right"] if options.has("right") else false,
		"fill" : options["fill"] if options.has("fill") else false,
		"center" : options["center"]  if options.has("center") else false,
		"ignorebbcode": options["ignorebbcode"] if options.has("ignorebbcode") else false
	}
	
	# Object which will be pushed into queue
	var obj : Dictionary = {
		"type": NORMAL_TEXT,
		"t": characterpersecond,
		"wl": PoolStringArray(text.split(" ")),
		"cw": -1,
		"ci": 0,
		"e": settings.event,
		"flags": []
		}
	# If the options object has a non default color, add a color attribute to the Object
	# Additionally add all the BBCode flags
	if !(settings.color.a == 0 && settings.color.r == 0 && settings.color.g == 1 && settings.color.b == 0):
		obj["c"] = settings.color
	# In the case that you want to write a single word in brackets without it being appended instantly set this to true
	if settings.ignorebbcode:
		obj["ignorebb"] = true
	if settings.bold:
		obj.flags.append("b")
	if settings.italic:
		obj.flags.append("i")
	if settings.underlined:
		obj.flags.append("u")
	if settings.strikethrough:
		obj.flags.append("s")
	if settings.code: 
		obj.flags.append("code")
	if settings.center:
		obj.flags.append("center")
	if settings.right:
		obj.flags.append("right")
	if settings.fill:
		obj.flags.append("fill")
	current_queue.append(obj)

# Push a wait time in seconds
func add_wait(time : float) -> void:
	current_queue.append({
		"type": WAIT,
		"t": time,
	})

func add_wait_for_interaction() -> void:
	current_queue.append({
		"type": WAIT_INPUT,
	})

func add_clear() -> void:
	current_queue.append({
		"type": CLEAR,
	})

# Add an image in the textbox, optional delay until it is added in seconds
# The intended way is to use images which are as high as the line, fix it yourself if you are using bigger images
func add_image(imagepath : String, time : float = 0) -> void:
	current_queue.append({
		"type": IMAGE,
		"t": time,
		"path": "[img]"+imagepath+"[/img]"
	})

# Add a linebreak
func add_newline() -> void:
	current_queue.append({
		"type": NEW_LINE
	})

# Add a pause, which has to be programatically be set to false
func add_pause() -> void:
	current_queue.append({
		"type": OPERATOR,
		"e": "pause"
	})

# Set the global color starting from this item
func set_color(color : Color) -> void:
	current_queue.append({
		"type": OPERATOR,
		"t": 0,
		"data": color,
		"e": "colorchange"
	})
	
# Append text differently depending on the current mode
func _append_text(text : String) -> void:
	if USE_APPEND_BBCODE:
		bbcodebuffer += text
#warning-ignore:return_value_discarded
		label.append_bbcode(text)
	else:
		label.bbcode_text += text

# Our resize event
func _on_resize() -> void:
	if USE_APPEND_BBCODE:
		label.clear()
#warning-ignore:return_value_discarded
		label.append_bbcode(bbcodebuffer)