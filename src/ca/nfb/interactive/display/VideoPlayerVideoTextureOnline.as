package ca.nfb.interactive.display {
	import com.adobe.utils.v3.AGALMiniAssembler;
	
	import flash.display.Stage;
	import flash.display.Stage3D;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DBufferUsage;
	import flash.display3D.Context3DProfile;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DRenderMode;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.Program3D;
	import flash.display3D.VertexBuffer3D;
	import flash.display3D.textures.VideoTexture;
	import flash.events.Event;
	import flash.events.VideoTextureEvent;
	
	import ca.nfb.interactive.data.MediaData;
	import ca.nfb.interactive.data.Strings;
	import ca.nfb.interactive.log.Log;
	
	public class VideoPlayerVideoTextureOnline extends AbstractVideoPlayer {
		private static const SIDE_LEFT:int = 0;
		private static const SIDE_MID:int = 1;
		private static const SIDE_RIGHT:int = 2;
		
		private var stage3D:Stage3D;
		private var ctx:Context3D;
		private var agalVersion:int = 1;
		
		private var vt:VideoTexture;
		
		private var vertexBuffer:VertexBuffer3D;
		private var indexBuffer:IndexBuffer3D;
		private var program:Program3D;
		private var assembler:AGALMiniAssembler;
		private var vertexShader:String;
		private var fragmentShader:String;
			
		private var lastType:int;
		private var texCount:int = 0;
		
		private var addedWithoutContext:Vector.<MediaData> = new Vector.<MediaData>();
		
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
		
		public function VideoPlayerVideoTextureOnline(stage:Stage, wid:Number, hei:Number, deviceName:String = "", deviceVersion:Number = 1) {
			super(stage, wid, hei);
			
			stage3D = stage.stage3Ds[0];
			stage3D.addEventListener(Event.CONTEXT3D_CREATE, onContextCreate);
			
			switch(deviceName) {
				case "iphone":
					if (deviceVersion <= 4) {
						profileIndex = 5;
					} else {
						profileIndex = 3;
					}
					break;
				case "ipad":
					if (deviceVersion <= 2) {
						profileIndex = 5;
					} else {
						profileIndex = 3;
					}
					break;
				case "android":
					profileIndex = 5;
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
			
			stage3D.requestContext3D(Context3DRenderMode.AUTO, profiles[profileIndex]);
		}
		
		private function onContextCreate(e:Event):void {
			ctx = stage3D.context3D;
			
			if (!ctx || ctx.driverInfo.indexOf("software") > -1) {
				Log.USE_LOG && Log.logmsg("VideoTexture Profile won't work - try lesser version: " + ctx.driverInfo);
				profileIndex++;
				ctx = null;
				stage3D.requestContext3D(Context3DRenderMode.AUTO, profiles[profileIndex]);
				return;
			}
			
			if (addedWithoutContext.length > 0) {
				var vid:MediaData;
				for (var i:int = addedWithoutContext.length - 1; i >= 0; i--) {
					vid = addedWithoutContext[i];
					vt = ctx.createVideoTexture();
					vt.addEventListener(VideoTextureEvent.RENDER_STATE, onRender);
					vid.videoTexture = vt;
					vt.attachNetStream(vid.netStream);
				}
				addedWithoutContext = new Vector.<MediaData>();
			}
			
			createProgram();
			createBuffers();
			createProjection();
			
			// Setup the back buffer. This is what actually displays stuff.
			// Note: Because it doesn't rescale within the video display container,
			// its dimensions are directly relevant to the stage instead.
			setStageDimensions(stageW, stageH);
			
			dispatchEvent(new Event(Event.CONTEXT3D_CREATE));
		}
		
		public override function addVideo(vid:MediaData):void {
			super.addVideo(vid);
			
			if (!ctx) {
				addedWithoutContext.push(vid);
				return;
			}
			
			vt = ctx.createVideoTexture();
			vt.addEventListener(VideoTextureEvent.RENDER_STATE, onRender);
			vid.videoTexture = vt;
			
			vid.netStream = setupNetConnection(vid.loadType != Strings.LOAD_PROGRESSIVE ? vid.url : null);
			vt.attachNetStream(vid.netStream);
		}
		
		public override function set maskLeftPos(value:Number):void {
			super.maskLeftPos = value;
			
			var wid:Number = halfMaskGapFrac * screenW;
			if (lastType == MediaData.TYPE_SEGMENTED_VID) {
				// Update vertex points if already playing segmented video.
				setVertexPointAt(4, SIDE_MID, value + wid, 0);
				setVertexPointAt(5, SIDE_MID, value - wid, screenH);
				setVertexPointAt(10, SIDE_LEFT, value - wid, screenH);
				setVertexPointAt(11, SIDE_LEFT, value + wid, 0);
			}
		}
		
		public override function set maskRightPos(value:Number):void {
			super.maskRightPos = value;
			
			var wid:Number = halfMaskGapFrac * screenW;
			if (lastType == MediaData.TYPE_SEGMENTED_VID) {
				// Update vertex points if already playing segmented video.
				setVertexPointAt(0, SIDE_RIGHT, value + wid, 0);
				setVertexPointAt(1, SIDE_RIGHT, value - wid, screenH);
				setVertexPointAt(6, SIDE_MID, value - wid, screenH);
				setVertexPointAt(7, SIDE_MID, value + wid, 0);
			}
		}
		
		public override function resize(wid:Number, hei:Number):void {
			super.resize(wid, hei);
			setStageDimensions(wid, hei);
		}
		
		public override function setStageDimensions(wid:Number, hei:Number):void {
			super.setStageDimensions(wid, hei);
			
			var vid:MediaData;
			for (var id:String in vidHash) {
				if (vidHash[id].active && !vid) {
					vid = vidHash[id];
				}
			}
			if (!vid) { return; }
			
			setVideoDimensions(id, wid, hei);
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
			ctx.setProgramConstantsFromVector(
				Context3DProgramType.VERTEX,
				0,
				Vector.<Number>([xRat, yRat, 0, 0]),
				1
			);
		}
		
		public override function showVideo(name:String, active:Boolean=true):void {
			super.showVideo(name, active);
			var vid:MediaData = vidHash[name];
			if (!vid) { return; }
			
			// Changed video. Update the video's scale.
			setVideoDimensions(name, stageW, stageH);
		}
		
		public override function seek(time:Number):void {
			super.seek(time);
			currentMedia.netStream.seek(time);
		}
		
		public override function update():void {
			// Clear a black screen.
			ctx.clear(0, 0, 0, 1);
			
			var vid:MediaData = currentMedia;
			if (vid != lastMedia) {
				// Only update videoTexture if type is different from last update.
				ctx.setTextureAt(0, vid.videoTexture as VideoTexture);
				lastMedia = vid;
			}
			
			var type:int = vid.playType; // Type comes from vid. Fix it!
			if (type != lastType) {
				switch(type) {
					case MediaData.TYPE_FULL_VID:
					case MediaData.TYPE_MASKED_VID:
						// Update the vectors to only point at the full video.
						vertexBuffer.uploadFromVector(Vector.<Number>([
							-1, 1, 0, 0, 0, // TOP-LEFT
							-1, -1, 0, 0, 1, // BOTTOM-LEFT
							1, -1, 0, 1, 1, // BOTTOM-RIGHT
							1, 1, 0, 1, 0 // TOP-RIGHT
						]), 0, 4);
						indexBuffer.uploadFromVector(Vector.<uint>([
							0,1,2,
							0,2,3
						]), 0, 6);
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
						
						indexBuffer.uploadFromVector(Vector.<uint>([
							0,1,2,
							0,2,3,
							4,5,6,
							4,6,7,
							8,9,10,
							8,10,11
						]), 0, 18);
						break;
					default: break;
				}
				lastType = type;
			}
			
			ctx.drawTriangles(indexBuffer, 0, type == MediaData.TYPE_SEGMENTED_VID ? 6 : 2);
			ctx.present();
		}
		
		private function onTexture(e:Event):void {
			Log.USE_LOG && Log.logmsg("Texture ready.");
		}
		
		private function onRender(e:VideoTextureEvent):void {
			Log.USE_LOG && Log.logmsg("ON RENDER: ");
			Log.USE_LOG && Log.logmsg(e.status + " --- " + e.colorSpace + " --- " + e.codecInfo);
			Log.USE_LOG && Log.logmsg(ctx.driverInfo + " --- " + ctx.profile);
		}
		
		/** ORIGINAL:
		private function createProgram():void {
			program = ctx.createProgram();
			
			// Create the vertex shader.
			assembler = new AGALMiniAssembler();
			vertexShader = assembler.assemble(Context3DProgramType.VERTEX,
				"mov vt0, va0\n" + // Store in temporary value vt0.
				
				"mul vt0.x, vt0.x, vc0.x\n" + // Scale
				"mul vt0.y, vt0.y, vc0.y\n" +
				
				"mov op, vt0\n" + // Sets the vertex position. The shader now knows where to draw the vertex.
				"mov v0, va1\n" // Send the texture coord to fragment shader.
			);
			
			// Create the fragment shader.
			fragmentShader = assembler.assemble(Context3DProgramType.FRAGMENT,
				"tex oc, v0, fs0 <2d,clamp,linear>\n" // Set the color to what we got from the texture. The shader now knows what to draw.
			);
			
			// Upload the code. The program is complete.
			program.upload(vertexShader, fragmentShader);
			ctx.setProgram(program);
		}
		*/
		
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
		
		private function createBuffers():void {
			// Create vertex buffer and upload it to context.
			vertexBuffer = ctx.createVertexBuffer(12, 5, Context3DBufferUsage.STATIC_DRAW);
			
			// Positions of the vertices.
			var vertices:Vector.<Number> = Vector.<Number>([
				// Left mask.
				-1, 1, 0, 0, 0, // TOP-LEFT
				-1, -1, 0, 0, 1, // BOTTOM-LEFT
				1, -1, 0, 1, 1, // BOTTOM-RIGHT
				1, 1, 0, 1, 0, // TOP-RIGHT
				
				// Middle mask.
				-1, 1, 0, 0, 0, // TOP-LEFT
				-1, -1, 0, 0, 1, // BOTTOM-LEFT
				1, -1, 0, 1, 1, // BOTTOM-RIGHT
				1, 1, 0, 1, 0, // TOP-RIGHT
				
				// Right mask.
				-1, 1, 0, 0, 0, // TOP-LEFT
				-1, -1, 0, 0, 1, // BOTTOM-LEFT
				1, -1, 0, 1, 1, // BOTTOM-RIGHT
				1, 1, 0, 1, 0  // TOP-RIGHT
			]);
			vertexBuffer.uploadFromVector(vertices, 0, 12);
			
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
			
			// Partition the buffers so each register knows what each chunk contains.
			ctx.setVertexBufferAt(0, vertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3); // This goes to "va0"
			ctx.setVertexBufferAt(1, vertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2); // This goes to "va1"
			
			// Create index buffer.
			indexBuffer = ctx.createIndexBuffer(18, Context3DBufferUsage.STATIC_DRAW);
			indexBuffer.uploadFromVector(Vector.<uint>([
				0,1,2,
				0,2,3,
				4,5,6,
				4,6,7,
				8,9,10,
				8,10,11
			]), 0, 18);
		}
		
		private function createProjection():void {
			var proj:Vector.<Number> = Vector.<Number>([1, 1, 0, 0]);
			
			// Add projection matrix to the vertex shader.
			ctx.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 0, proj, 1);
		}
		
		public function getActiveVideoData():MediaData {
			var vid:MediaData;
			for (var i:int = 0, l:int = vidOrder.length; i < l; i++) {
				vid = vidHash[vidOrder[i]];
				if (vid.active) {
					return vid;
				}
			}
			return null;
		}
		
		/** Set vertex position. */
		private function setVertexPointAt(index:int, side:int, x:Number, y:Number):void {
			var rX:Number = x / screenW;
			var rY:Number = y / screenH;
			
			var secX:Number = 0;
			var secY:Number = 0;
			
			// Something's off with the y value. Might be an issue with the float precision.
			var half:Number = .4965;
			
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
			
			var v:Vector.<Number> = Vector.<Number>([
				(rX * 2) - 1,
				-(rY * 2) + 1,
				0,
				(rX * .5) + secX,
				(rY * half) + secY
			]);
			
			vertexBuffer.uploadFromVector(v, index, 1);
		}
	}
}