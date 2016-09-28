package ca.nfb.interactive.content {
	import com.gskinner.motion.GTween;
	import com.gskinner.motion.GTweener;
	import com.gskinner.motion.easing.Sine;
	
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.text.TextField;
	
	import ca.nfb.interactive.log.Log;
	
	public class LoadScreen extends Sprite {
		
		private static const TEXT_SLIDE_DIST:Number = 30;
		
		public var loadingText:LoadingText;
		public var percent:TextField;
		public var lineSplit:LoadSplitLine;
		
		private var w:Number;
		private var h:Number
		
		private var maskContainer:Sprite;
		private var maskUpper:Sprite;
		private var maskLower:Sprite;
		
		private var _loadPercent:int = 0;
		private var _targetScale:Number = 1;
		private var _isAnimating:Boolean = false;
		
		public function LoadScreen(width:Number, height:Number) {
			super();
			w = width;
			h = height;
			
			maskUpper = new Sprite();
			maskLower = new Sprite();
			maskUpper.graphics.beginFill(0x00FF00, 0);
			maskUpper.graphics.drawRect(-w * .5, -h * .5, w, h * .5);
			maskLower.graphics.beginFill(0x0000FF, 0);
			maskLower.graphics.drawRect(-w * .5, 0, w, h * .5);
			maskContainer = new Sprite();
			maskContainer.addChild(maskUpper);
			maskContainer.addChild(maskLower);
			addChild(maskContainer);
			
			_targetScale = (h / lineSplit.height) - 1;
			
			addEventListener(Event.ADDED_TO_STAGE, init);
			
			setLanguage("en");
		}
		
		public function setLanguage(lang:String):void {
			loadingText.gotoAndStop(lang || 0);
		}
		
		private function init(e:Event):void {
			removeEventListener(Event.ADDED_TO_STAGE, init);
			animateIn();
		}
		
		/** Returns load percent, from 0 to 100. */
		public function get loadPercent():int {
			return _loadPercent;
		}
		
		/** Set load percent. Takes values 0 to 100. */
		public function set loadPercent(value:int):void {
			if (_loadPercent == value) { return; }
			_loadPercent = Math.min(100, value);
			render();
		}
		
		/** Adds percent to the current load percentage. */
		public function addLoadPercent(value:int):void {
			if (_loadPercent >= 100) { return; }
			_loadPercent += value;
			_loadPercent = Math.min(100, _loadPercent);
			render();
		}
		
		/** Updates load screen based on new loadPercent. */
		private function render():void {
			percent.text = _loadPercent + "%";
			if (!_isAnimating) {
				var scale:Number = (_targetScale * Number(_loadPercent / 100)) + 1;
				GTweener.removeTweens(lineSplit);
				GTweener.to(lineSplit, 1, {scaleX: scale, scaleY: scale}, {ease: Sine.easeInOut}).onComplete = handleTweenComplete;
				if (_loadPercent >= 100) {
					animateOut();
				}
			}
		}
		
		/** Animated load screen in from nothingness. */
		private function animateIn():void {
			Log.USE_LOG && Log.logmsg("Animate In LoadScreen");
			_isAnimating = true;
			loadingText.alpha = 0;
			percent.alpha = 0;
			lineSplit.scaleX = 0;
			lineSplit.scaleY = 0;
			lineSplit.alpha = 0;
			var scale:Number = (_targetScale * Number(_loadPercent / 100)) + 1;
			GTweener.to(lineSplit, 1.5, {scaleX: scale, scaleY: scale, alpha: 1}, {ease: Sine.easeInOut}).onComplete = function (g:GTween):void {
				handleTweenComplete(g);
				var scale:Number = (_targetScale * Number(_loadPercent / 100)) + 1;
				GTweener.to(lineSplit, 1, {scaleX: scale, scaleY: scale}, {ease: Sine.easeInOut}).onComplete = handleTweenComplete;
				
				var textX:Number = loadingText.x;
				var percentX:Number = percent.x;
				loadingText.x += TEXT_SLIDE_DIST;
				percent.x -= TEXT_SLIDE_DIST;
				loadingText && (GTweener.to(loadingText, 1, {x: textX, alpha: 1}, {ease: Sine.easeInOut}).onComplete = handleTweenComplete);
				GTweener.to(percent, 1.5, {x: percentX, alpha: 1}, {ease: Sine.easeInOut}).onComplete = function (g:GTween):void {
					handleTweenComplete(g);
					_isAnimating = false;
					Log.USE_LOG && Log.logmsg("Animate In LoadScreen Complete");
					if (_loadPercent >= 100) {
						// Completed load during animation. Animate out.
						animateOut();
					} else {
						render();
					}
				}
			}
		}
		
		/** Animate out to black screen and dispatch COMPLETE event. */
		private function animateOut():void {
			if (_isAnimating) { return; }
			_isAnimating = true;
			
			lineSplit.mask = maskContainer;
			
			GTweener.to(maskUpper, .5, {y: -h * .5}, {ease: Sine.easeInOut}).onComplete = handleTweenComplete;
			GTweener.to(maskLower, .5, {y: h * .5}, {ease: Sine.easeInOut}).onComplete = handleTweenComplete;
			loadingText && (GTweener.to(loadingText, .5, {x: loadingText.x + TEXT_SLIDE_DIST, alpha: 0}, {ease: Sine.easeInOut}).onComplete = handleTweenComplete);
			GTweener.to(percent, .5, {x: percent.x - TEXT_SLIDE_DIST, alpha: 0}, {ease: Sine.easeInOut}).onComplete = function (g:GTween):void {
				handleTweenComplete(g);
				_isAnimating = false;
				dispatchEvent(new Event(Event.COMPLETE));
			}
		}
		
		/** Tween cleanup. */
		private function handleTweenComplete(g:GTween):void {
			GTweener.remove(g);
		}
	}
}