#!/bin/bash

TIMEOUT=300
WAIT_TIME=10

SCREEN_WIDTH=1920
SCREEN_HEIGHT=1080
TEMPLATE_WIDTH=`convert template.png -format "%w" info:`
TEMPLATE_HEIGHT=`convert template.png -format "%h" info:`
MAX_X=$(( $SCREEN_WIDTH - $TEMPLATE_WIDTH ))
MAX_Y=$(( $SCREEN_HEIGHT - $TEMPLATE_HEIGHT ))

MPLAYER_CONTROL=/tmp/mplayer_control
GPIO_BASE=/sys/class/gpio
BUTTON=3
LED=4

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

export_pin() {
    if [ ! -f $GPIO_BASE/gpio$1 ]; then
	echo $1 > $GPIO_BASE/export
    fi
}

pin_mode() {
    echo $2 > $GPIO_BASE/gpio$1/direction
}

set_value() {
    echo $2 > $GPIO_BASE/gpio$1/value
}

get_value() {
    cat $GPIO_BASE/gpio$1/value
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

new_image() {
    x_offset=$(( $RANDOM % $MAX_X ))
    y_offset=$(( $RANDOM % $MAX_Y ))
    composite -geometry +$x_offset+$y_offset template.png canvas.png out.jpg
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

shutdown() {
    rm out.jpg
    rm canvas.png
    rm $MPLAYER_CONTROL
    echo "quit" > $MPLAYER_CONTROL
    setterm -cursor on
    echo "done."
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

trap "shutdown" EXIT

# turn off cursor
setterm -cursor off

# generate background canvas
convert -size $SCREEN_WIDTH"x"$SCREEN_HEIGHT xc:black canvas.png

# generate initial image
new_image

# set up & launch mplayer
if [ ! -f $MPLAYER_CONROL ]; then
   mkfifo $MPLAYER_CONTROL
else
    rm $MPLAYER_CONTROL
    mkfifo $MPLAYER_CONTROL
fi
mplayer -vo fbdev2 -loop 0 -slave -tv driver=v4l2:buffersize=16:width=1920:height=1080:outfmt=MJPEG -input file=$MPLAYER_CONTROL "mf://out.jpg" 2> mplayer.error > mplayer.log &

# set up button for input
export_pin $BUTTON
pin_mode $BUTTON "in"

# set up light
export_pin $LED
pin_mode $LED "out"
set_value $LED 1

# initialize variables
VAL_OLD=`get_value $BUTTON`

old_time=`date +%s`

echo "BEGIN MAIN LOOP"

while [ 1 ]
do
    current_time=`date +%s`
    #echo $(( $current_time - $old_time ))
    VAL=`get_value $BUTTON`
    if [ $VAL != $VAL_OLD ]; then
	if [ $VAL = "0" ]; then
	    # button pressed, switch to tv://
	    echo loadfile tv:// > $MPLAYER_CONTROL
	    set_value $LED 0
	    sleep $TIMEOUT
	    new_image
	    echo loadfile "mf://out.jpg" > $MPLAYER_CONTROL
            set_value $LED 1
	fi
    elif [ $(( $current_time - $old_time )) -ge $WAIT_TIME ]; then
	# change the image currently shown
	new_image
	echo loadfile "mf://out.jpg" > $MPLAYER_CONTROL
	old_time=`date +%s`
    fi
    
    VAL_OLD=$VAL
done


