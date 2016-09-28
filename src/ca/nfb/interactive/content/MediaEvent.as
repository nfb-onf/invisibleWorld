package ca.nfb.interactive.content {
	import flash.events.Event;
	
	public class MediaEvent extends Event {
		
		public static const UPDATE_FOOTER_LABEL:String = "UPDATE_FOOTER_LABEL"
		public static const STOP_MUSIC:String = "STOP_MUSIC"
		public static const PLAY_MUSIC:String = "PLAY_MUSIC"
			
		
		public var audioTitle:String
		
		public function MediaEvent(type:String, audioTitle:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{			
			this.audioTitle = audioTitle
			
			super(type, bubbles,cancelable)
		}
		public override function clone():Event
		{
			return new MediaEvent(type,audioTitle, bubbles, cancelable);
		}
	}
}