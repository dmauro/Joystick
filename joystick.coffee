###
Copyright 2013 David Mauro

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Joystick is a wrapper for the in-development Gamepad API.

version 0.0.1
###

button_names = [
    "face_bottom"
    "face_right"
    "face_left"
    "face_top"
    "bumper_left"
    "bumper_right"
    "trigger_left"
    "trigger_right"
    "select"
    "start"
    "thumbstick_left_click"
    "thumbstick_right_click"
    "dpad_up"
    "dpad_down"
    "dpad_left"
    "dpad_right"
    "home"
]

axis_names = [
    "left_hori"
    "left_vert"
    "right_hori"
    "right_vert"
]

# We only do a shallow copy of this, so use primitives
default_settings =
    trigger_threshold   : 0.5
    axis_threshold      : 0.5
    analog_rounding     : 1

class JoystickManager
    constructor: (settings) ->
        @settings = {}
        for setting, value of default_settings
            @settings[setting] = settings?[setting] or value
        @connected_joysticks = {}
        @previous_states = {}

    add_listeners: ->
        @on_joystick_connect = (event) =>
            @add_joystick event.gamepad
            @polling_start() unless @is_polling

        @on_joystick_disconnect = (event) =>
            @remove_joystick event.gamepad

        @on_button_down = (event) =>
            @button_down event.gamepad, event.button

        @on_button_up = (event) =>
            @button_up event.gamepad, event.button

        @on_axis_move = (event) =>
            @axis_move event.gamepad, event.axis, event.value

        @event_types = [
                event_names : ["MozGamepadConnected"]
                listener    : @on_joystick_connect
            ,
                event_names : ["MozGamepadDisconnected"]
                listener    : @on_joystick_disconnect
            ,
                event_names : ["MozGamepadButtonDown"]
                listener    : @on_button_down
            ,
                event_names : ["MozGamepadButtonUp"]
                listener    : @on_button_up
            ,
                event_names : ["MozGamepadAxisMove"]
                listener    : @on_axis_move
        ]

        for event_type in @event_types
            for event_name in event_type.event_names
                window.addEventListener event_name, event_type.listener

    remove_listeners: ->
        for event_type in @event_types
            for event_name in event_type.event_names
                window.removeEventListener event_Name, event_type.listener

    polling_start: ->
        @is_polling = true
        @poll()

    polling_stop: ->
        @is_polling = false

    poll: ->
        return unless @is_polling
        @poll_for_new_joysticks()
        @update_joysticks()
        window.requestAnimationFrame =>
            @poll()

    add_joystick: (joystick) ->
        @connected_joysticks[joystick.index] = joystick

    remove_joystick: (joystick) ->
        delete @connected_joysticks[joystick.index]

    poll_for_new_joysticks: ->
        _check_for_new = (joystick_array) =>
            for joystick in joystick_array
                if joystick and not @connected_joysticks[joystick.index]?
                    @add_joystick joystick

        if navigator.webkitGamepads?
            _check_for_new navigator.webkitGamepads
        else if navigator.webkitGetGamepads?
            _check_for_new navigator.webkitGetGamepads()

    clone_joystick_object: (joystick, reset=false) ->
        buttons = []
        axes = []
        for button in joystick.buttons
            buttons.push if reset then 0 else button
        for axis in joystick.axes
            axes.push if reset then 0 else axis
        return {
            id          : joystick.id
            index       : joystick.index
            timestamp   : joystick.timestamp
            buttons     : buttons
            axes        : axes
        }

    round_analog: (num) ->
        return num if @settings.analog_rounding < 0
        pow = Math.pow(10, @settings.analog_rounding)
        return Math.round(num * pow)/pow

    update_joysticks: ->
        for index, joystick of @connected_joysticks
            # Timestamp shortcut
            continue if joystick.timestamp? and joystick.timestamp is @previous_states[joystick.index]?.timestamp

            # Clone the joystick to freeze it and prevent updates midstride
            # in case we use events in the future
            joystick = @clone_joystick_object joystick

            # Init previous state if needed
            unless @previous_states[joystick.index]
                @previous_states[joystick.index] = @clone_joystick_object joystick, true

            for i in [0...joystick.buttons.length]
                button = joystick.buttons[i]
                prev_button = @previous_states[joystick.index].buttons[i]

                if button_names[i] in ["trigger_right", "trigger_left"]
                    if button > @settings.trigger_threshold and prev_button <= @settings.trigger_threshold
                        @button_down joystick, i
                        @trigger_engaged joystick, i
                    else if button <= @settings.trigger_threshold and prev_button > @settings.trigger_threshold
                        @button_up joystick, i
                        @trigger_released joystick, i
                else
                    if button isnt prev_button
                        if @round_analog(button) isnt @round_analog(@previous_states[joystick.index].buttons[i])
                            difference = @round_analog(button) - @round_analog(@previous_states[joystick.index].buttons[i])
                            if difference is 1
                                @button_down joystick, i
                            else if difference is -1
                                @button_up joystick, i
                            else if button_names[i] in ["trigger_right", "trigger_left"]
                                @trigger_move joystick, i, button


            for i in [0...joystick.axes.length]
                axis = joystick.axes[i]
                prev_axis = @previous_states[joystick.index].axes[i]

                if @round_analog(axis) isnt @round_analog(@previous_states[joystick.index].axes[i])
                    @axis_move joystick, i, axis

                if (axis > @settings.axis_threshold and prev_axis <= @settings.axis_threshold) or
                   (axis < -@settings.axis_threshold and prev_axis >= -@settings.axis_threshold)
                    @axis_engaged joystick, i, if prev_axis > 0 then 1 else -1
                else if (axis <= @settings.axis_threshold and prev_axis > @settings.axis_threshold) or
                        (axis >= -@settings.axis_threshold and prev_axis < -@settings.axis_threshold)
                    @axis_released joystick, i, if prev_axis > 0 then 1 else -1

            # Save the clone as previous state
            @previous_states[joystick.index] = joystick

    button_down: (joystick, button_id) ->
        console.log "Button down", joystick.index, button_names[button_id]

    button_up: (joystick, button_id) ->
        console.log "Button up", joystick.index, button_names[button_id]

    trigger_engaged: (joystick, button_id) ->
        console.log "Trigger engaged", joystick.index, button_names[button_id]

    trigger_released: (joystick, button_id) ->
        console.log "Trigger released", joystick.index, button_names[button_id]

    trigger_move: (joystick, button_id, value) ->
        console.log "Trigger move", joystick.index, button_names[button_id], @round_analog value

    axis_engaged: (joystick, axis_id, direction) ->
        console.log "Axis engaged", joystick.index, axis_names[axis_id], direction

    axis_released: (joystick, axis_id, direction) ->
        console.log "Axis released", joystick.index, axis_names[axis_id], direction

    axis_move: (joystick, axis_id, value) ->
        console.log "Axis move", joystick.index, axis_names[axis_id], @round_analog value

# Public
_last_joystick_manager = null

_use_polling = ->
    return true

window.joystick =
    init: (settings) ->
        return console.log "Joystick not supported in your browser :(" unless window.joystick.supported()
        joystick_manager = new JoystickManager settings
        # Either start polling, or add listeners
        if _use_polling()
            joystick_manager.polling_start()
        else
            joystick_manager.add_listeners()
        return _last_joystick_manager = joystick_manager

    supported: ->
        return navigator.webkitGamepads? or navigator.webkitGetGamepads?