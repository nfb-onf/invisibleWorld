package ca.nfb.interactive.data {
	public class MediaSegment {
		
		public var name:String;
		public var url:String;
		public var start:Number;
		public var next:String;
		
		public function MediaSegment(data:Object) {
			name = data.name;
			url = data.url;
			start = data.start;
			next = data.next;
		}
	}
}