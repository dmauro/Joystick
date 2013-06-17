#!/bin/bash

cd ~/Projects/Joystick
rm joystick.js
coffee -c joystick.coffee
coffee -c requestAnimationFrame.coffee
cat requestAnimationFrame.js joystick.js > combined.js
rm requestAnimationFrame.js
rm joystick.js
java -jar compiler.jar --js combined.js --js_output_file joystick.min.js
rm combined.js
mv joystick.min.js joystick.js
echo "/* Joystick version 0.0.1 */"|cat - joystick.js > /tmp/out && mv /tmp/out joystick.js
