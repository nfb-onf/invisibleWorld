package ca.nfb.interactive.content {
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	
	public class CreditsScreen extends Sprite {
		
		private static const PADDING:int = 100;
		private static const SCROLL_SPEED:Number = 2;
		private static const CLOSE_BTN_SIZE:Number = 43;
		
		private var content:MovieClip;
		private var credCloseBtn:MovieClip;
		
		private var wid:Number;
		private var hei:Number;
		
		public function CreditsScreen() {
			super();
			
			// Content's origin is at top-left.
			content = new CreditsScreenContent();
			addChild(content);
			
			credCloseBtn = new ButtonClose();
			credCloseBtn.width = credCloseBtn.height = CLOSE_BTN_SIZE;
			addChild(credCloseBtn);
			credCloseBtn.addEventListener(MouseEvent.CLICK, closeCredits, false, 0, true);
			
			setLanguage("en");
		}
		
		public function setLanguage(lang:String):void {
			content.gotoAndStop(lang || 0);
		}
		
		public function setSize(w:Number, h:Number):void  {
			wid = w;
			hei = h;
			credCloseBtn.x = w - PADDING;
			credCloseBtn.y = PADDING;
			
			content.x = w * .5;
			content.y = h;
		}
		
		public function update():void {
			if (content.y + content.height > 0) {
				content.y -= SCROLL_SPEED;
				if (content.y + content.height < 0) {
					reset();
					dispatchEvent(new Event(Event.CLOSE));
				}
			}
		}
		
		public function reset():void {
			content.y = hei;
		}
		
		private function closeCredits(e:MouseEvent):void {
			reset();
			dispatchEvent(new Event(Event.CLOSE));
		}
		
	}
}