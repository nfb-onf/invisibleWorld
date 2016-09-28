package ca.nfb.interactive.content {
	import flash.display.Bitmap;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.net.URLRequest;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.text.TextLineMetrics;
	import flash.utils.Timer;
	
	import ca.nfb.interactive.data.AboutImageData;
	import ca.nfb.interactive.log.Log;
	import ca.nfb.interactive.utils.TweenUtil;
	
	public class AboutScreen extends Sprite {
		
		private static const PADDING:int = 100;
		private static const SWAP_TIME:int = 15000;
		
		private var content:MovieClip;
		
		private var fullText:String;
		private var aboutText:TextField;
		private var subText:TextField;
		private var aboutImage:MovieClip;
		private var aboutImageArray:Vector.<AboutImageData>;
		private var currImageIndex:int = 0;
		private var aboutTextSections:Vector.<String>;
		private var aboutTextIndex:int = 0;
		private var abtScrollD:MovieClip;
		private var abtScrollU:MovieClip;
		private var abtCloseBt:MovieClip;
		
		private var autoImageSwap:Boolean = true;
		private var autoImageTimer:Timer;
		
		private var loaders:Array = [];
		
		public function AboutScreen() {
			super();
			
			content = MovieClip(new AboutScreenContent());
			addChild(content);
			content.x = PADDING * .5;
			content.y = PADDING * .5;
			
			aboutImage = MovieClip(content.abtImage);
			aboutImage.visible = false;
			
			subText = TextField(content.subTxt);
			subText.wordWrap = true;
			
			aboutText = TextField(content.abtTxt);
			aboutText.wordWrap = true;
			aboutText.width = aboutImage.x + aboutImage.width - aboutText.x;
			
			abtScrollD = MovieClip(content.scrollDown);
			abtScrollU = MovieClip(content.scrollUp);
			abtCloseBt = MovieClip(content.clsBtn);
			
			abtScrollD.addEventListener(MouseEvent.CLICK, aboutNext, false, 0, true);
			abtScrollU.addEventListener(MouseEvent.CLICK, aboutPrev, false, 0, true);
			abtCloseBt.addEventListener(MouseEvent.CLICK, closeAbout, false, 0, true);
			
			abtScrollD.visible = false;
			abtScrollU.visible = false;
			
			autoImageTimer = new Timer(SWAP_TIME);
			autoImageTimer.addEventListener(TimerEvent.TIMER, onSwapImage, false, 0, true);
		}
		
		public function toggleAutoImageSwap(active:Boolean):void {
			autoImageSwap = active;
			(active && aboutImageArray && aboutImageArray.length) ? autoImageTimer.start() : autoImageTimer.stop();
		}
		
		public function setImages(xmlList:XMLList, lang:String = "en"):void {
			// Parse XMLList into AboutImageData objects.
			aboutImageArray = new Vector.<AboutImageData>();
			var aid:AboutImageData;
			for each (var imageUrl:XML in xmlList.*) {
				if (String(imageUrl.@lang) != lang) { continue; }
				aid = new AboutImageData();
				aid.url = String(imageUrl.@url);
				aid.subtitle = String(imageUrl.@subtitle);
				aboutImageArray.push(aid);
			}
			
			if (aboutImageArray && aboutImageArray.length > 0) {
				// Contains images. Move text a bit.
				aboutText.width = aboutImage.x - aboutText.x - PADDING;
				
				// Create loaders to import images.
				var loader:Loader;
				for (var i:int = 0, l:int = aboutImageArray.length; i < l; i++) {
					loader = new Loader();
					aboutImageArray[i].loader = loader;
					loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoaderComplete, false, 0, true);
					loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onLoadError, false, 0, true);
					loader.load(new URLRequest(aboutImageArray[i].url));
					loaders[aboutImageArray[i].url] = loader;
				}
				
				// Start autoswapping images.
				if (autoImageSwap) {
					autoImageTimer.start();
				}
			} else {
				// No images. Text is full width.
				aboutText.width = aboutImage.x + aboutImage.width - aboutText.x;
				
				// Stop autoswapping images.
				if (autoImageSwap) {
					autoImageTimer.stop();
				}
			}
			
			// Move arrows to better positions under the text.
			abtScrollU.x = aboutText.x + (abtScrollU.width * .5);
			abtScrollD.x = aboutText.x + aboutText.width - (abtScrollU.width * .5);
			
			// Update text alignment.
			setText(fullText, lang);
		}
		
		public function setSize(w:Number, h:Number):void  {
			content.width = w - PADDING;
			content.height = h - PADDING;
		}
		
		public function setText(value:String, lang:String = "en"):void {
			fullText = value;
			aboutText.text = value;
			
			var format:TextFormat = aboutText.defaultTextFormat;
			format.font = (lang == "kh") ? "Khmer OS" : "Tungsten-Medium";
			aboutText.setTextFormat(format);
			aboutText.defaultTextFormat = format;
			
			// Split the text up into lines, using aboutText as the boundary.
			var lineArray:Vector.<String> = new Vector.<String>();
			var lastLine:int = 0;
			var test:String;
			for (var i:int = 0; i < aboutText.numLines; i++) {
				test = aboutText.getLineText(i);
				if (test.replace(/\s*/, "") != "") {
					// Only add lines if not empty and not line breaks.
					if (i - lastLine > 2) {
						// Should be an extra line break here. Add one.
						lineArray.push("\n");
					}
					lineArray.push(test);
					lastLine = i;
				}
			}
			
			if (lineArray.length > 0) {
				aboutTextSections = new Vector.<String>();
				var textChunk:String = "";
				
				// Get general text height. Line break lines don't change height for some reason.
				aboutText.text = lineArray[0];
				var met:TextLineMetrics = aboutText.getLineMetrics(0);
				var textHeight:Number = 0;
				var lineHeight:Number = aboutText.textHeight + met.leading;
				aboutText.text = "";
				
				// Get chunks of text that fit in the text box.
				for (i = 0; i < lineArray.length; i++) {
					textHeight += lineHeight;
					
					if (textHeight >= aboutText.height) {
						// That's enough now. Store chunk and start new one.
						aboutTextSections.push(textChunk);
						textHeight = lineHeight;
						textChunk = lineArray[i];
					} else {
						// Not enough text. Add to chunk.
						textChunk += lineArray[i];
					}
				}
				
				// Push final incomplete chunk.
				aboutTextSections.push(textChunk);
				
				// Done. We have an array of visible text chunks for aboutText.
				if (aboutTextSections.length > 1) {
					abtScrollD.visible = true;
				}
				
			} else {
				aboutTextSections = new Vector.<String>(1);
				aboutTextSections[0] = "No description available.";
			}
			
			// Reset the text index and update.
			aboutTextIndex = 0;
			update();
		}
		
		public function update():void {
			aboutText.text = aboutTextSections[aboutTextIndex];
			if (aboutImageArray && aboutImageArray.length > 0) {
				subText.text = aboutImageArray[currImageIndex].subtitle;
			}
			abtScrollD.visible = (aboutTextIndex < aboutTextSections.length - 1);
			abtScrollU.visible = (aboutTextIndex > 0);
		}
		
		private function aboutNext(e:MouseEvent):void {
			aboutTextIndex = Math.min(aboutTextSections.length - 1, aboutTextIndex + 1);
			update();
		}
		
		private function aboutPrev(e:MouseEvent):void {
			aboutTextIndex = Math.max(0, aboutTextIndex - 1);
			update();
		}
		
		private function closeAbout(e:MouseEvent):void {
			dispatchEvent(new Event(Event.CLOSE));
		}
		
		private function onSwapImage(e:TimerEvent):void {
			if (aboutImageArray[currImageIndex].bitmap) {
				TweenUtil.fadeOutBmp(aboutImageArray[currImageIndex].bitmap);
			}
			
			currImageIndex++;
			if (currImageIndex >= aboutImageArray.length) { currImageIndex = 0; }
			
			if (aboutImageArray[currImageIndex].bitmap) {
				TweenUtil.fadeInBmp(aboutImageArray[currImageIndex].bitmap);
			}
			update();
		}
		
		private function onLoadError(e:IOErrorEvent):void {
			Log.USE_LOG && Log.logmsg(e.type + " " + e.errorID + ": " + e.text);
		}
		
		private function onLoaderComplete(e:Event):void {
			return;
			var loaderInfo:LoaderInfo = e.target as LoaderInfo;
			loaderInfo.removeEventListener(Event.COMPLETE, onLoaderComplete, false);
			
			var newImage:Bitmap = loaderInfo.content as Bitmap;
			content.addChild(newImage);
			
			// Clear out loader reference.
			delete loaders[loaderInfo.url];
			
			// Setup the image.
			var targetRatio:Number = aboutImage.width / aboutImage.height;
			var imageRatio:Number = newImage.width / newImage.height;
			if (imageRatio > targetRatio) {
				newImage.width = aboutImage.width;
				newImage.height = aboutImage.width / imageRatio;
			} else {
				newImage.width = aboutImage.height * imageRatio;
				newImage.height = aboutImage.height;
			}
			
			// Center the image and start it invisible.
			newImage.x = aboutImage.x + ((aboutImage.width - newImage.width) * .5);
			newImage.y = aboutImage.y + ((aboutImage.height - newImage.height) * .5);
			newImage.visible = false;
			newImage.alpha = 0;
			
			if (aboutImageArray.length == 1) {
				// First image! Make sure it shows.
				currImageIndex = 0;
				aboutImageArray[0].bitmap = newImage;
				newImage.visible = true;
				newImage.alpha = 1;
			} else {
				for (var i:int = aboutImageArray.length - 1; i >= 0; i--) {
					if (aboutImageArray[i].loader.contentLoaderInfo == loaderInfo) {
						aboutImageArray[i].bitmap = newImage;
						if (i == currImageIndex) {
							newImage.visible = true;
							newImage.alpha = 1;
						}
						break;
					}
				}
			}
			
		}
	}
}