package ca.nfb.interactive.display.events {
	import flash.events.Event;
	
	public class VideoPlayerEvent extends Event {
		
		public static const 
			BUFFER_EMPTY:String = "bufferEmpty",
			BUFFER_FULL:String = "bufferFull",
			MEDIA_LOADED:String = "mediaLoaded",
			MEDIA_FAILED:String = "mediaFailed",
			MEDIA_PROGRESS:String = "mediaProgress",
			PLAY_COMPLETE:String = "playComplete",
			RESIZED:String = "resized",
			SEEK_COMPLETE:String = "seekComplete";
		
		public var data:Object;
		
		public function VideoPlayerEvent(type:String, data:Object = null) {
			super(type, bubbles, cancelable);
			this.data = data;
		}
	}
}