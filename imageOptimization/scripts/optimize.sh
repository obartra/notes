#!/bin/bash

filename=$(basename $1)
extension="${filename##*.}"
filename="${filename%.*}"

function compare {
	optimized_size=$(stat --printf="%s" "$1")
	input_size=$(stat --printf="%s" "$2")

	# Only replace input if it is smaller
	if [ "$input_size" -gt "$optimized_size" ]; then
		echo "Input $3 file optimized"
		mv "$1" "$2"
	else
		echo "Unable to optimize $3 any further"
		rm "$1"
	fi
}

function removeIfUseless {
	optimized_size=$(stat --printf="%s" "$1")
	input_size=$(stat --printf="%s" "$2")

	# Remove if optimized image is larger
	if [ "$input_size" -ge "$optimized_size" ]; then
		echo "Optimized $3 generated"
	else
		rm "$1"
	fi
}

# Generate WEBP
for ext in jpeg jpg gif png; do
	if [[ $extension == $ext ]]; then
		cwebp "$1" -q 80 -o "$filename.webp" -quiet
		removeIfUseless "$filename.webp" $1 "webp"
	fi
done

# Generate JXR
for ext in jpeg jpg; do
	if [[ $extension == $ext ]]; then
		convert "$1" "$filename.bmp"
		JxrEncApp -i "$filename.bmp" -o "$filename.jxr" -q 0.65
		rm "$filename.bmp"
		removeIfUseless "$filename.jxr" $1 "jxr"
	fi
done

# Optimize / Overwrite input JPG
for ext in jpeg jpg; do
	if [[ $extension  == $ext ]]; then
		mozjpeg -optimize "$1" > "$filename.tmp"
		compare "$filename.tmp" "$1" "jpg"
	fi
done

# Optimize / Overwrite input PNG
if [[ $extension == "png" ]]; then
	pngquant --speed 1 --force -o "$filename.tmp" -- "$1"
	compare "$filename.tmp" "$1" "png"
fi
