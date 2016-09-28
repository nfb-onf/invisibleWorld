package ca.nfb.interactive.display {
	import com.adobe.utils.v3.AGALMiniAssembler;
	
	import flash.display.BitmapData;
	import flash.display.Stage;
	import flash.display.Stage3D;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DBufferUsage;
	import flash.display3D.Context3DProfile;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DRenderMode;
	import flash.display3D.Context3DTextureFormat;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.VertexBuffer3D;
	import flash.display3D.textures.Texture;
	import flash.display3D.textures.VideoTexture;
	import flash.events.AsyncErrorEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.VideoTextureEvent;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	
	import ca.nfb.interactive.data.MediaData;
	import ca.nfb.interactive.data.MediaSegment;
	import ca.nfb.interactive.data.Strings;
	import ca.nfb.interactive.display.events.VideoPlayerEvent;
	import ca.nfb.interactive.log.Log;
	
	public class VideoPlayerVideoTexture extends AbstractVideoPlayer {
		private static const SIDE_LEFT:int = 0;
		private static const SIDE_MID:int = 1;
		private static const SIDE_RIGHT:int = 2;

		private static const LOAD_ATTEMPT_MAX:int = 2;
		
		private var stage3D:Stage3D;
		private var ctx:Context3D;
		
		private var bgt:Texture;
		private var vt:VideoTexture;
		private var nc:NetConnection;
		private var ns:NetStream;
		
		private var vertexVector:Vector.<Number>;
		private var vertexBuffer:VertexBuffer3D;
		private var indexBuffer:IndexBuffer3D;
		private var assembler:AGALMiniAssembler;
		private var vertexShader:String;
		private var fragmentShader:String;
		
		private var loadAttemptCount:int = 0;
		private var alwaysUpdate:Boolean = false;
		private var playbackReady:Boolean = false;
		
		private var profileIndex:int = 0;
		private var profiles:Array = [
			Context3DProfile.STANDARD_EXTENDED,
			Context3DProfile.STANDARD,
			Context3DProfile.STANDARD_CONSTRAINED,
			Context3DProfile.BASELINE_EXTENDED,
			Context3DProfile.BASELINE,
			Context3DProfile.BASELINE_CONSTRAINED,
		];
		private var versions:Array = [
			3,
			2,
			1,
			1,
			1,
			1,
		];
		
		public function VideoPlayerVideoTexture(stage:Stage, wid:Number, hei:Number, deviceName:String = "", deviceVersion:Number = 1) {
			super(stage, wid, hei);
			
			stage3D = stage.stage3Ds[0];
			stage3D.addEventListener(Event.CONTEXT3D_CREATE, onContextCreate);
			
			switch(deviceName) {
				case "iphone":
					if (deviceVersion <= 4) {
						profileIndex = 5;
					} else {
						profileIndex = 2;
					}
					alwaysUpdate = true;
					break;
				case "ipad":
					if (deviceVersion <= 2) {
						profileIndex = 5;
					} else {
						profileIndex = 2;
					}
					alwaysUpdate = true;
					break;
				case "android":
					profileIndex = 2;
					break;
				case "mac":
					profileIndex = 1;
					break;
				case "windows":
					profileIndex = 1;
					break;
				default:
					profileIndex = 4;
					break;
			}
			
			nc = new NetConnection();
			nc.client = {onBWDone: handleBWDone};
			nc.addEventListener(AsyncErrorEvent.ASYNC_ERROR, handleNCAsyncError);
			nc.addEventListener(NetStatusEvent.NET_STATUS, handleNCStatus);
			nc.addEventListener(IOErrorEvent.IO_ERROR, handleNCIOError);
			nc.addEventListener(SecurityErrorEvent.SECURITY_ERROR, handleNCSecurityError);
			nc.connect(null);
			
			ns = new NetStream(nc);
			ns.addEventListener(NetStatusEvent.NET_STATUS, handleNSStatus);
			ns.addEventListener(AsyncErrorEvent.ASYNC_ERROR, handleNSAsyncError);
			ns.addEventListener(IOErrorEvent.IO_ERROR, handleNSIOError);
			ns.client = { onMetaData: handleMetaData };
			
			ns.checkPolicyFile = true;
			ns.useHardwareDecoder = true;
			ns.inBufferSeek = true;
			ns.bufferTime = 2;
			ns.bufferTimeMax = 30;
			ns.soundTransform = volumeControl;
			
			Log.USE_LOG && Log.logmsg("Use profile: " + profiles[profileIndex]);
			stage3D.requestContext3D(Context3DRenderMode.AUTO, profiles[profileIndex]);
		}
		
		private function onContextCreate(e:Event):void {
			ctx = stage3D.context3D;
			
			// DEBUG
			ctx.enableErrorChecking = true;
			ctx.configureBackBuffer(stageW, stageH, 0, false);
			
			// VideoTexture.
			vt = ctx.createVideoTexture();
			vt.addEventListener(VideoTextureEvent.RENDER_STATE, onRender, false, 0, true);
			vt.attachNetStream(ns);
			
			// Display dummy texture until videos play.
			bgt = ctx.createTexture(16, 16, Context3DTextureFormat.BGRA, true);
			var data:BitmapData = new BitmapData(16, 16, false, 0);
			bgt.uploadFromBitmapData(data);
			ctx.setTextureAt(0, bgt);
			
			Log.USE_LOG && Log.logmsg("Context3D Driver: " + ctx.driverInfo);
			
			if (!ctx || ctx.driverInfo.indexOf("software") > -1) {
				Log.USE_LOG && Log.logmsg("VideoTexture Profile won't work - try lesser version: " + ctx.driverInfo);
				profileIndex++;
				ctx = null;
				stage3D.requestContext3D(Context3DRenderMode.AUTO, profiles[profileIndex]);
				return;
			}
			
			createProgram();
			createBuffers();
			createProjection();
			
			// Setup the back buffer. This is what actually displays stuff.
			// Note: Because it doesn't rescale within the video display container,
			// its dimensions are directly relevant to the stage instead.
			setStageDimensions(stageW, stageH);
			
			// Setup update method.
			if (alwaysUpdate) {
				addEventListener(Event.ENTER_FRAME, doUpdateAlways, false, 0, true);
			} else {
				vt.addEventListener(Event.TEXTURE_READY, onTexture, false, 0, true);
			}
			
			dispatchEvent(new Event(Event.CONTEXT3D_CREATE));
		}
		
		public override function get bufferLength():Number {
			return ns.bufferLength;
		}
		
		public override function get time():Number {
			if (!currentMedia) { return 0; }

			//Log.USE_LOG && Log.logmsg("TIME: " + ns.time + " - " + (currentMedia.currentSegment ? currentMedia.currentSegment.name + ": " + currentMedia.currentSegment.start : "No segment"));
 			if (currentMedia.currentSegment) {
				return currentMedia.currentTime + currentMedia.currentSegment.start;
			} else {
				return currentMedia.currentTime;
			}
		}
		
		public override function set maskLeftPos(value:Number):void {
			super.maskLeftPos = value;
			if (!currentMedia) { return; }
			
			var wid:Number = halfMaskGapFrac * screenW;
			if (currentMedia.playType == MediaData.TYPE_SEGMENTED_VID) {
				// Update vertex points if already playing segmented video.
				setVertexPointAt(4, SIDE_MID, value + wid, 0);
				setVertexPointAt(5, SIDE_MID, value - wid, screenH);
				setVertexPointAt(10, SIDE_LEFT, value - wid, screenH);
				setVertexPointAt(11, SIDE_LEFT, value + wid, 0);
				vertexBuffer.uploadFromVector(vertexVector, 0, 12);
			}
			
			if (!currentMedia.playing) {
				// Update context if paused. Otherwise we can't slide masks visibly.
				show();
			}
		}
		
		public override function set maskRightPos(value:Number):void {
			super.maskRightPos = value;
			if (!currentMedia) { return; }
			
			var wid:Number = halfMaskGapFrac * screenW;
			if (currentMedia.playType == MediaData.TYPE_SEGMENTED_VID) {
				// Update vertex points if already playing segmented video.
				setVertexPointAt(0, SIDE_RIGHT, value + wid, 0);
				setVertexPointAt(1, SIDE_RIGHT, value - wid, screenH);
				setVertexPointAt(6, SIDE_MID, value - wid, screenH);
				setVertexPointAt(7, SIDE_MID, value + wid, 0);
				vertexBuffer.uploadFromVector(vertexVector, 0, 12);
			}
			
			if (!currentMedia.playing) {
				// Update context if paused. Otherwise we can't slide masks visibly.
				show();
			}
		}
		
		public override function set volume(value:Number):void {
			super.volume = value;
			ns.soundTransform = volumeControl;
		}
		
		public override function resize(wid:Number, hei:Number):void {
			// Resizing the video means resizing to the stage.
			setStageDimensions(wid, hei);
			dispatchEvent(new VideoPlayerEvent(VideoPlayerEvent.RESIZED));
		}
		
		public override function setStageDimensions(wid:Number, hei:Number):void {
			super.setStageDimensions(wid, hei);
			if (currentMedia) {
				setVideoDimensions(currentMedia.videoName, wid, hei);
			}
		}
		
		public override function setVideoDimensions(name:String, wid:Number, hei:Number):void {
			super.setVideoDimensions(name, wid, hei);
			if (!ctx) { return; }
			
			// Buffer's min width and height is 50x50.
			var truWid:Number = Math.max(stageW, 50);
			var truHei:Number = Math.max(stageH, 50);
			
			// Scale the context to the real stage width/height.
			ctx.configureBackBuffer(truWid, truHei, 0, false);
			
			var vid:MediaData = vidHash[name];
			
			// Keep the aspect ratio.
			var videoRatio:Number = wid / hei;
			var screenRatio:Number = screenW / screenH;
			var real:Number;
			var xRat:Number = wid / truWid;
			var yRat:Number = hei / truHei;
			if (videoRatio > screenRatio) {
				real = hei * screenRatio;
				xRat = real / truWid;
			} else {
				real = wid / screenRatio;
				yRat = real / truHei;
			}
			
			// Add projection vector to the vertex shader.
			Log.USE_LOG && Log.logmsg("Set video ratios: " + xRat + " - " + yRat);
			ctx.setProgramConstantsFromVector(
				Context3DProgramType.VERTEX,
				0,
				Vector.<Number>([xRat, yRat, 0, 0]),
				1
			);
		}
		
		public override function addVideo(vid:MediaData):void {
			super.addVideo(vid);
			
			// Just to have the references handy.
			vid.netConnection = nc;
			vid.netStream = ns;
			
			// Videos don't load until called to play. Dispatch this immediately.
			dispatchEvent(new VideoPlayerEvent(VideoPlayerEvent.MEDIA_PROGRESS, 1));
			dispatchEvent(new VideoPlayerEvent(VideoPlayerEvent.MEDIA_LOADED));
		}
		
		public override function showVideo(name:String):void {
			super.showVideo(name);
			
			// Do some checks with the last media.
			if (lastMedia) {
				// Remove the net status listener.
				ns.removeEventListener(NetStatusEvent.NET_STATUS, lastMedia.onNetStatus);
			}
			
			ns.addEventListener(NetStatusEvent.NET_STATUS, currentMedia.onNetStatus);
			
			lastMedia = currentMedia;
			
			if (currentMedia.segments && !currentMedia.currentSegment) {
				// Uses segments. Get the current media's segment based on time.
				for (var i:int = currentMedia.segments.length - 1; i >= 0 && !currentMedia.currentSegment; i--) {
					if (currentMedia.currentTime >= currentMedia.segments[i].start) {
						currentMedia.currentSegment = currentMedia.segments[i];
					}
				}
			}
			
			if (currentMedia.loadType == Strings.LOAD_STREAMING) {
				// Stream video.
				currentMedia.loaded = false;
				nc.connect(currentMedia.baseStreamUrl);
			} else {
				nc.connect(null);
				beginNSLoad();
			}
			
			// Update the vertex vectors and buffers.
			var type:int = currentMedia.playType;
			switch(type) {
				case MediaData.TYPE_FULL_VID:
				case MediaData.TYPE_MASKED_VID:
					// Update the vectors to only point at the full video.
					vertexVector.splice(0, 20,
						-1, 1, 0, 0, 0, // TOP-LEFT
						-1, -1, 0, 0, 1, // BOTTOM-LEFT
						1, -1, 0, 1, 1, // BOTTOM-RIGHT
						1, 1, 0, 1, 0 // TOP-RIGHT
					);
					vertexBuffer.uploadFromVector(vertexVector, 0, 4);
					break;
				case MediaData.TYPE_SEGMENTED_VID:
					// Split up the video.
					var wid:Number = halfMaskGapFrac * screenW;
					
					setVertexPointAt(0, SIDE_RIGHT, rightMaskX + wid, 0);
					setVertexPointAt(1, SIDE_RIGHT, rightMaskX - wid, screenH);
					setVertexPointAt(2, SIDE_RIGHT, screenW, screenH);
					setVertexPointAt(3, SIDE_RIGHT, screenW, 0);
					
					setVertexPointAt(4, SIDE_MID, leftMaskX + wid, 0);
					setVertexPointAt(5, SIDE_MID, leftMaskX - wid, screenH);
					setVertexPointAt(6, SIDE_MID, rightMaskX - wid, screenH);
					setVertexPointAt(7, SIDE_MID, rightMaskX + wid, 0);
					
					setVertexPointAt(8, SIDE_LEFT, 0, 0);
					setVertexPointAt(9, SIDE_LEFT, 0, screenH);
					setVertexPointAt(10, SIDE_LEFT, leftMaskX - wid, screenH);
					setVertexPointAt(11, SIDE_LEFT, leftMaskX + wid, 0);
					
					vertexBuffer.uploadFromVector(vertexVector, 0, 12);
					break;
				default: break;
			}
			
			// Changed video. Update the video's scale.
			setVideoDimensions(name, stageW, stageH);
			
			// Change alwaysUpdate's listener to VideoTexture TEXTURE_READY.
			if (alwaysUpdate && hasEventListener(Event.ENTER_FRAME)) {
				Log.USE_LOG && Log.logmsg("Revert to VIDEOTEXTURE TEXTURE_READY.");
				removeEventListener(Event.ENTER_FRAME, doUpdateAlways, false);
				vt.addEventListener(Event.TEXTURE_READY, onTexture, false, 0, true);
			}
		}
		
		public override function seek(time:Number):void {
			super.seek(time);
			
			if (currentMedia.segments) {
				// Uses segments. Check the segment at new time.
				var segment:MediaSegment = currentMedia.getSegmentByTime(time);
				nsSeekTarget = time - segment.start;
				currentMedia.currentTime = nsSeekTarget;
				
				if (segment != currentMedia.currentSegment) {
					// New segment! Switch it off!
					currentMedia.currentSegment = segment;
					beginNSLoad();
				} else if (!nsSeeking) {
					// Same segment. Seek it.
					ns.seek(nsSeekTarget);
				}
			} else if (!nsSeeking) {
				nsSeekTarget = time;
				ns.seek(nsSeekTarget);
				currentMedia.currentTime = nsSeekTarget;
				
				if (nsStopped) {
					// Video has stopped. Call "play" to make it work again.
					nsStopped = false;
					Log.USE_LOG && Log.logmsg(" ----- REPLAY " + currentMedia.url);
					ns.play(currentMedia.url);
				}
			}
		}
		
		public override function resume():void {
			super.resume();
			ns.resume();
			if (alwaysUpdate) {
				removeEventListener(Event.ENTER_FRAME, doUpdateAlways, false);
			}
		}
		
		public override function pause():void {
			super.pause();
			ns.pause();
			if (alwaysUpdate) {
				addEventListener(Event.ENTER_FRAME, doUpdateAlways, false, 0, true);
			}
		}
		
		public override function hide():void {
			ctx.clear(0, 0, 0, 0);
		}
		
		public override function show():void {
			ctx.clear(0, 0, 0, 1);
			ctx.drawTriangles(indexBuffer, 0, (currentMedia.playType == MediaData.TYPE_SEGMENTED_VID) ? 6 : 2);
			ctx.present();
		}
		
		public function doUpdateAlways(e:Event = null):void {
			ctx.clear(0, 0, 0, 1);
			ctx.drawTriangles(indexBuffer, 0, (currentMedia && currentMedia.playType == MediaData.TYPE_SEGMENTED_VID) ? 6 : 2);
			ctx.present();
		}
		
		public override function update():void { 
			// Update does nothing. TextureReady makes the draw.
		}
		
		/** Create graphics card rendering program. */
		private function createProgram():void {
			// Create the vertex shader.
			assembler = new AGALMiniAssembler();
			vertexShader = 
				"mov vt0, va0\n" + // Store in temporary value vt0.
				
				"mul vt0.x, vt0.x, vc0.x\n" + // Scale
				"mul vt0.y, vt0.y, vc0.y\n" +
				
				"mov op, vt0\n" + // Sets the vertex position. The shader now knows where to draw the vertex.
				"mov v0, va1\n" // Send the texture coord to fragment shader.
			;
			
			// Create the fragment shader.
			fragmentShader = 
				"tex oc, v0, fs0 <2d,clamp,nearest>\n"; // Set the color to what we got from the texture. The shader now knows what to draw.
			
			// Upload the code. The program is complete.
			ctx.setProgram(
				assembler.assemble2(ctx, versions[profileIndex], vertexShader, fragmentShader)
			);
		}
		
		/** Create buffer vectors. */
		private function createBuffers():void {
			// Create vertex buffer and upload it to context.
			vertexBuffer = ctx.createVertexBuffer(12, 5, Context3DBufferUsage.DYNAMIC_DRAW);
			
			// Positions of the vertices.
			vertexVector = new Vector.<Number>(60);
			
			var wid:Number = halfMaskGapFrac * screenW;
			
			setVertexPointAt(0, SIDE_RIGHT, rightMaskX + wid, 0);
			setVertexPointAt(1, SIDE_RIGHT, rightMaskX - wid, screenH);
			setVertexPointAt(2, SIDE_RIGHT, screenW, screenH);
			setVertexPointAt(3, SIDE_RIGHT, screenW, 0);
			
			setVertexPointAt(4, SIDE_MID, leftMaskX + wid, 0);
			setVertexPointAt(5, SIDE_MID, leftMaskX - wid, screenH);
			setVertexPointAt(6, SIDE_MID, rightMaskX - wid, screenH);
			setVertexPointAt(7, SIDE_MID, rightMaskX + wid, 0);
			
			setVertexPointAt(8, SIDE_LEFT, 0, 0);
			setVertexPointAt(9, SIDE_LEFT, 0, screenH);
			setVertexPointAt(10, SIDE_LEFT, leftMaskX - wid, screenH);
			setVertexPointAt(11, SIDE_LEFT, leftMaskX + wid, 0);
			
			vertexBuffer.uploadFromVector(vertexVector, 0, 12);
			
			// Partition the buffers so each register knows what each chunk contains.
			ctx.setVertexBufferAt(0, vertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3); // This goes to "va0"
			ctx.setVertexBufferAt(1, vertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2); // This goes to "va1"
			
			// Create index buffer.
			indexBuffer = ctx.createIndexBuffer(18, Context3DBufferUsage.DYNAMIC_DRAW);
			indexBuffer.uploadFromVector(Vector.<uint>([
				0,1,2,
				0,2,3,
				4,5,6,
				4,6,7,
				8,9,10,
				8,10,11
			]), 0, 18);
		}
		
		/** Create camera projection matrix. */
		private function createProjection():void {
			var proj:Vector.<Number> = Vector.<Number>([1, 1, 0, 0]);
			
			// Add projection matrix to the vertex shader.
			ctx.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 0, proj, 1);
		}
		
		/** Begin loading NetStream. */
		private function beginNSLoad():void {
			nsSeeking = true;
			nsLoading = true;
			currentMedia.loaded = true;
			
			if (currentMedia.currentSegment) {
				Log.USE_LOG && Log.logmsg("Load segment URL: " + currentMedia.currentSegment.url);
				ns.play(currentMedia.currentSegment.url);
				ns.pause();
			} else {
				Log.USE_LOG && Log.logmsg("Load URL: " + currentMedia.url);
				ns.play(currentMedia.url);
				nsSeekTarget = 0;
				ns.seek(nsSeekTarget);
				addEventListener(Event.ENTER_FRAME, handleNSProgress, false, 0, true);
			}
			
			prevBandwidthTime = new Date().time;
			prevBandwidthBytesLoaded = 0;
			
			ctx.setTextureAt(0, vt);
			
			progressPercent = 0;
			loadingMedia = currentMedia;
		}
		
		/** Set vertex position. */
		private function setVertexPointAt(index:int, side:int, x:Number, y:Number):void {
			var rX:Number = x / screenW;
			var rY:Number = y / screenH;
			
			var secX:Number = 0;
			var secY:Number = 0;
			
			// Something's off with the y value. Might be an issue with the float precision.
			var half:Number = versions[profileIndex] == 1 ? .5 : .4965;
			
			switch (side) {
				case SIDE_LEFT:
					secX = 0;
					secY = 0;
					break;
				case SIDE_MID:
					secX = .5;
					secY = 0;
					break;
				case SIDE_RIGHT:
					secX = .5;
					secY = half;
					break;
			}
			
			vertexVector.splice(index * 5, 5,
				(rX * 2) - 1,
				-(rY * 2) + 1,
				0,
				(rX * .5) + secX,
				(rY * half) + secY
			);
		}
		
		protected override function handleNCStatus(e:NetStatusEvent):void {
			super.handleNCStatus(e);
			if (e.info.code == "NetConnection.Connect.Success" && currentMedia && !currentMedia.loaded) {
				beginNSLoad();
			}
		}
		
		protected override function handleNSStatus(e:NetStatusEvent):void {
			super.handleNSStatus(e);
			if (e.info.code == "NetStream.Seek.Complete") {
				// Seek is successful. Only called by streams.
				currentMedia.currentTime = ns.time;
				nsSeeking = false;
			}
		}
		
		/** VideoTexture got a new texture. This means rendering is complete. Update. */
		private function onTexture(e:Event):void {
			if (nsSeekTarget == -1) {
				// Not seeking. Good.
				currentMedia.currentTime = ns.time;
			} else {
				if (Math.abs(ns.time - nsSeekTarget) > 2) {
					// NetStream hasn't finished seeking yet.
				} else {
					nsSeekTarget = -1;
				}
			}
			
			ctx.clear(0, 0, 0, 1);
			ctx.drawTriangles(indexBuffer, 0, currentMedia.playType == MediaData.TYPE_SEGMENTED_VID ? 6 : 2);
			ctx.present();
		}
		
		/** Context3D's render state changed. */
		private function onRender(e:VideoTextureEvent):void {
			if (e.status == "software" && loadAttemptCount < LOAD_ATTEMPT_MAX) {
				// Software mode? That's not right. Try loading it again.
				loadAttemptCount++;
				lastMedia = null;
				showVideo(currentMedia.videoName);
			} else {
				// Accelerated! ... or we're stuck on software. Render anyways.
				loadAttemptCount = 0;
				currentMedia.playing ? ns.resume() : ns.pause();
				if (nsLoading) {
					nsLoading = false;
					seek(currentMedia.currentTime);
				}
			}
		}
	}
}