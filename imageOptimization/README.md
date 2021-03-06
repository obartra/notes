# Optimizing Images for the web

HTML has evolved immensely since the `<IMG>` tag was [first proposed](http://1997.webhistory.org/www.lists/www-talk.1993q1/0182.html). Today, images account for a large portion of all network traffic on most sites. In fact, just optimizing images can lead to significant boosts in general page performance and SEO.

Unfortunately, there isn't a cross-browser compatible solution that takes advantage of modern compression algorithms.

## Formats

To bridge this gap, different vendors have developed different solutions. On the purest 90's browser-war style, no vendor has implemented any solution other than their own.

- Google developed the [WebP](https://en.wikipedia.org/wiki/WebP) format, which is available for Chrome and Opera
- Microsoft created [JPEG XR](https://en.wikipedia.org/wiki/JPEG_XR) (JXR), as an improvement over JPEG. It is available on IE9+ and MS Edge
- Mozilla has invested in [mozjpeg](https://en.wikipedia.org/wiki/Libjpeg), a fork of libjpeg-turbo that achieves ~10% better compression

Thus, we are forced to conditionally serve images on different formats if we want to deliver the most optimized possible option.

![Formats Comparison](assets/formats.png)

When we create these files, we need to know if the optimized images look good. We want to compress each image as much as we can without loosing quality. There are several ways to do that, here we'll use SSIM.

## SSIM

[SSIM](https://en.wikipedia.org/wiki/Structural_similarity) is a value from 0 to 100% that rates how similar two images will be perceived by a human viewer. SSIM results correlate with other approaches like [PSNR](https://en.wikipedia.org/wiki/Peak_signal-to-noise_ratio) but SSIM has higher sensitivity to JPEG compression artifacts ([A. Horé and D. Ziou, 2010](https://www.semanticscholar.org/paper/Image-Quality-Metrics-PSNR-vs-SSIM-Hor%C3%A9-Ziou/cfab5b500506078117125146c0d283d2392ff2e3/pdf)).

At around 95% SSIM differences are not discernible by most people ([JR. Flynn et al., 2013](https://www.semanticscholar.org/paper/Image-Quality-Assessment-Using-the-SSIM-and-the-Flynn-Ward/056e28a107a2ff32114a24b7ec33dc6b18752766/pdf)). The exact number depends on the person, the image, distance from the screen and lighting (among other factors). For that reason, 95% is not an absolute number, but it should be a good enough approximation for most purposes.

To asses SSIM values we'll use a [script](http://www.fmwconcepts.com/imagemagick/ssim/index.php) that relies on [image magick](https://www.imagemagick.org/script/index.php). I've included a copy of the file under [scripts/ssim.sh](scripts/ssim.sh).

## Goals (TL;DR)

We want to:

- Serve `.webp` when the browser support them
- Fallback to Serve `.jxr` on IE9+ and MS Edge
- Serve optimized `.png` and `.jpg` otherwise
- Maintain a SSIM >= 95%
- Automate image format generation
- Automate image serving

## Install

Let's set up our environment so that we can generate and optimize these images.


```bash
#!/bin/bash

sudo apt-get update
sudo apt-get install libjpeg-dev libpng-dev libtiff-dev libgif-dev webp libjxr-tools autoconf automake libtool nasm make pngquant imagemagick

wget https://github.com/mozilla/mozjpeg/releases/download/v3.1/mozjpeg-3.1-release-source.tar.gz
tar -xvf mozjpeg-3.1-release-source.tar.gz
cd mozjpeg
autoreconf -fiv
mkdir build && cd build
sh ../configure
sudo make install

# Make /opt/mozjpeg/bin/jpegtran available as mozjpeg
sudo ln -s /opt/mozjpeg/bin/jpegtran /usr/local/bin/mozjpeg
```

**TIP**: If you want to reproduce these steps as you read, you can clone [this repo](https://github.com/obartra/notes) and `cd` to the `imageOptimization` folder.

## WebP

WebP supports transparency and animations so it's a good option for compressing `png`, `jpg`, `jpeg` and `gif` files.

Let's say we receive `assets/input.jpg` to optimize. It's a `jpg` image saved at already a decently small file size (63.2kb).

![Formats Comparison](assets/input.jpg)

The webp compressor (`cwebp`) takes an input file, a quality parameter and an output file:

```bash
cwebp assets/input.jpg -q 80 -o assets/output-q80.webp
```

That generates a 31.2kb image (about ~2x smaller). These are impressive savings! But how do we know if it's noticeably different from the input?

We want to be able to generate these images programmatically so we don't want to manually verify each one of them. Here is where SSIM comes in:

```bash
./scripts/ssim.sh assets/input.jpg assets/output-q80.webp
# ssim=0.945 dssim=0.055
```

If we want a higher compression we can just change the quality parameter. For instance `-q 65` leads to a SSIM of 93% and a file size of 24.1kb. It's up to us where we strike the balance between quality and compression.

| Quality | WebP 80 | WebP 65 | WebP 10 |
|---|---|---|---|
| Image |![Q80](assets/output-q80.webp) | ![Q65](assets/output-q65.webp) | ![Q10](assets/output-q10.webp) |
| Size | 31.2kb | 24.1kb | 9.6kb |
| SSIM | 94.5% | 93% | 88% |

## JXR

The process for JXR is similar to that of WebP but JxrEncApp input formats are restricted to `bmp`, `tif` and `hdr` 😨

We can use `imagemagick` to generate an equivalent `bmp`. Since `bmp` is lossless there shouldn't be a concern for degradation. Let's try it:

```bash
convert assets/input.jpg assets/intermediate.bmp
JxrEncApp -i assets/intermediate.bmp -o assets/output-q65.jxr -q 0.65
rm assets/intermediate.bmp
```

Similarly, we can also play with the quality setting to modify the SSIM and file size.

| Quality | JXR 80 | JXR 65 | JXR 10 |
|---|---|---|---|
| Image |![Q80](assets/output-q80.jxr) | ![Q65](assets/output-q65.jxr) | ![Q10](assets/output-q10.jxr) |
| Size | 87.0kb | 66.8kb | 17.0kb |
| SSIM | 96% | 95% | 90% |

## JPEG and PNG

But what if someone visits our site and they are not using IE, Edge, Chrome or Opera? Maybe they are on Firefox, Safari or some other browser. We need to optimize for these cases as well.

Given the same `assets/input.jpg` we would do:

```bash
mozjpeg -optimize assets/input.jpg > assets/output.jpg
```

In this case our input image was already an optimized `jpeg` and `mozjpeg` wasn't able to obtain any additional gains. That happens some times. On occasion a `jxr` or a `webp` file will even be larger than the input `jpeg`.

These should be edge cases but we need to account for them so that we don't end up serving larger files.

Finally, if the input image was a `png` we would optimize it like:

```
pngquant --speed 1 -o assets/output.png -- assets/input.png
```

That output has a SSIM of 94% and a file size of 64.8kb (x3 smaller than the input `png`).

| Quality | Unoptimized PNG | Optimized PNG |
|---|---|---|---|
| Image |![no-optim](assets/input.png) | ![optim](assets/output.png) |
| Size | 206.1kb | 64.8kb |
| SSIM | N/A | 94% |

## Serving Images

We've started with a single `assets/input.jpg`. At this point we should have an optimized version of the `jpg` file, a `webp` one and `jxr` one. How do we deliver them to the right user?

There are several potential approaches:

### Front End Solutions

If we need to support an image-heavy application that would benefit from `webp` optimizations, it may be worth [polyfilling browser WebP support](https://webpjs.appspot.com/) and only serve that format.

We could also use a library like [Modernizr](https://modernizr.com/) to detect [WebP support](https://modernizr.com/download?setclasses&q=webp). Our code would then look something like this:

```javascript
const imgs = Array.from(document.querySelectorAll('img'));
Modernizr.on('webp', supportsWebP => {
	if (supportsWebP) {
		imgs.forEach(img => {
			img.src = img.src.replace(/.(jpe?|pn)g$/, '.webp');
		});
	}
});
```

But that gets messy quickly. We could go with an HTML/CSS only option by using the `<picture>` or `<object>` tags:

```html
<object>
	<source srcset="assets/output-q65.webp" type="image/webp">
	<source srcset="assets/output-q65.jxr" type="image/jxr">
	<source srcset="assets/output.jpg" type="image/jpeg">
	<img src="assets/output.jpg">
</object>
```

For a more in-depth look at this last approach, you may want to check Jeremy Wagner's [post](https://jeremywagner.me/blog/webp-images) on the topic. While this approach works well, it causes some overhead for each image added. We also need to make sure all resources exist on the backend. For these reasons, we may want to look for a server side solution instead.

### Back End Solutions

When we send a `GET` request for an image, the HTTP request already contains information on the supported file types for our browser. This allows us to seamlessly re-write paths.

If you are using [express](https://github.com/expressjs/express) or [Connect](https://github.com/senchalabs/connect/) you can check out [webp-jxr-middleware](https://github.com/obartra/webp-jxr-middleware) that does just that.

At its core, `webp-jxr-middleware` would do something look like:

```javascript
import { join } from 'path';
import express from 'express';
import { parse } from 'url';

const app = express();

function replacePath() {
	return function (request, response, next) {
		if (request.headers.accept.includes('image/webp')) {
			request.url = request.url.replace(/.(jpe?g|png)$/, '.webp');
			response.set('Content-Type', 'image/webp');
		} else if (request.headers.accept.includes('image/jxr')) {
			request.url = request.url.replace(/.jpe?g$/, '.jxr');
			response.set('Content-Type', 'image/jxr');
		}
		next();
	}
}

app.listen(8888);
app.use(replacePath());
app.use(express.static(path));
```

## Automation

The Back End approach solves automating serving the right images but, how do we automate image generation?

Combining the previous scripts, we can generate `WebP`, `JXR` and optimize `PNG`s and `JPEG`s:

```bash
#!/bin/bash

filename=$(basename $1)
extension="${filename##*.}"
filename="${filename%.*}"

# Generate WebP format
for ext in jpeg jpg gif png; do
	if [[ $extension == $ext ]]; then
		cwebp $1 -q 80 -o "$filename.webp"
	fi
done

# Optimize PNG
if [[ $extension  == "png" ]]; then
	pngquant --speed 1 --force -o "$filename.tmp" -- "$1"
fi

# Generate JXR and optimize JPG
for ext in jpeg jpg; do
	if [[ $extension  == $ext ]]; then
		convert $1 "$filename.bmp"
		JxrEncApp -i "$filename.bmp" -o "$filename.jxr" -q 0.65
		rm "$filename.bmp"
		mozjpeg -optimize $1 > "$filename.tmp"
		mv "$filename.tmp" $1
	fi
done

```

For a more complete script that also guarantees file size gains into account check [scripts/optimize.sh](scripts/optimize.sh).
