package ca.nfb.interactive.data {
	import flash.display.MovieClip;
	import flash.text.TextField;
	
	public class SectionLink extends Object {
		public var title:String;
		public var time:Number;
		public var ttxt:TextField;
		public var clip:MovieClip;	
		public var secOutline:MovieClip;
		
		public function SectionLink():void {
			title = '';
			time = 0;
			clip = new TimelineMarker();
			ttxt = TextField(clip.getChildByName('ttxt'));
			secOutline = MovieClip(clip.getChildByName('secTitleOutline'));
		}
		
		public function gotoAndStop(frame:*):void {
			clip.gotoAndStop(frame);
			var label:String = ttxt.text;
			ttxt = TextField(clip.getChildByName('ttxt'));
			ttxt.text = title || label;
			
			secOutline = MovieClip(clip.getChildByName('secTitleOutline'));
		}
	}
}