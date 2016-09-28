package ca.nfb.interactive.content
{
	import flash.events.Event;
	
	public class TrackingEvent extends Event
	{
		public static const TRACK:String = "TRACK"
		
		public var strToTrack:String
		
		public function TrackingEvent(type:String,strToTrack:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			
			this.strToTrack = strToTrack
			super(type, bubbles, cancelable);
		}
		public override function toString():String{
			return '[LinkEvent type="'+type+'" strToTrack="'+strToTrack+'"]'
		}
		
		public override function clone():Event
		{
			return new TrackingEvent(type,strToTrack, bubbles, cancelable);
		}
	}
}