###
# Convert to CoffeeScript from:
# http://paulirish.com/2011/requestanimationframe-for-smart-animating/
# http://my.opera.com/emoller/blog/2011/12/20/requestanimationframe-for-smart-er-animating
# requestAnimationFrame polyfill by Erik Möller. fixes from Paul Irish and Tino Zijdel
# MIT license
###
(->
    last_time = 0
    vendors = ['ms', 'moz', 'webkit', 'o']
    for vendor in vendors
        continue if window.requestAnimationFrame
        window.requestAnimationFrame = window[vendor + "RequestAnimationFrame"]
        window.cancelAnimationFrame = window[vendor + "CancelAnimationFrame"] or window[vendor + "CancelRequestAnimationFrame"]

    unless window.requestAnimationFrame
        window.requestAnimationFrame = (callback, element) ->
            current_time = +new Date()
            time_to_call = Math.max 0, 16 - current_time - last_time
            id = window.setTimeout ->
                callback current_time + time_to_call
            , time_to_call
            last_time = current_time + time_to_call
            return id

    unless window.cancelAnimationFrame
        window.cancelAnimationFrame = (id) ->
            clearTimeout id
)()
