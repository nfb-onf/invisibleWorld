package ca.nfb.interactive.content{
	
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.geom.ColorTransform;
	import flash.text.Font;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.utils.getDefinitionByName;
	
	public class TopNav extends BaseNFB {
		
		public static var bar_height:Number = 30;
		
		private var bar:Sprite;
		private var btn:Sprite;
		private var textFormat:TextFormat;
		private var xml:XML;
		private var obj:Object;
		
		private var leftButtons:Vector.<Sprite> = new Vector.<Sprite>();
		private var rightButtons:Vector.<Sprite> = new Vector.<Sprite>();
		
		private var ctOn:ColorTransform = new ColorTransform(1, 1, .4, 1);
		private var ctOff:ColorTransform = new ColorTransform(1, 1, 1, .7);
		
		public function TopNav(obj:Object, linksXML:XML, width:Number, yPos:Number) {
			//add bar
			this.obj = obj;
			xml = linksXML;
			bar = new Sprite();
			addChild(bar);
			bar.graphics.beginFill(0x000000);
			bar.graphics.drawRect(0,0,30,bar_height);
			bar.graphics.endFill();
			bar.width = width;
			y = yPos;
			
			// we get a reference to the definition of the MyFont class (the class of our font created in the library)
			// we could have just used 'Standard0756' directly, but some editors, like FDT, complain about it, saying that the specified definition does not exist, and if we have errors, the editor will not give us code completion... correctly; 
			var MyFontClass:Class = getDefinitionByName("Arial") as Class;
			// create an instance of our font class
			var myFont : Font = new MyFontClass() as Font;
			
			// in order to specify what font we'll use for our textfield, we need a textformat object
			textFormat = new TextFormat();
			// set it's font property (String) to the name of our font
			// you might notice that we could have passed in the name of the font directly, hard coded; and it would have worked; but it's safer this way; fonts may have different names on different OSs, so when compiling the fla on a different OS, the font might not be found, thus the text will not be displayed; although you might argue that the font is there; also it's easier to change the font; only change it in library and recompile
			textFormat.font = myFont.fontName;
			// set font size
			textFormat.size = bar_height / 3;
			// set font tracking
			//textFormat.letterSpacing = 1;
			// set font color
			textFormat.color = 0xffffff;
			
			//add links
			var totalLinks:int = xml.links.link.length();
			var i:int, str:String, icon:String, side:String;
			var rightCount:int = 0, leftCount:int = 0;
			for(i=1; i<=totalLinks; i++){
				str = String(xml.links.link[i-1]);
				icon = xml.links.link[i-1].@icon.toString();
				side = xml.links.link[i-1].@side.toString();
				
				createTextBtn(
					i,
					str,
					side,
					icon ? getDefinitionByName(icon) as Class : null
				);
			}
		}
		
		private function createTextBtn(num:int, str:String, align:String = "left", icon:Class = null):void {
			btn = new Sprite();
			addChild(btn);
			btn.name = "btn" + num;
			btn.buttonMode = true;
			btn.mouseChildren = false;
			btn.transform.colorTransform = ctOff;
			// create the textField object
			var text : TextField = new TextField();
			text.name = "txt";
			// optionally set a name for the textfield, so we can refer to it, if we need to, later			
			// set the autosize option to "left"; using constants is more error proof
			text.autoSize = TextFieldAutoSize.LEFT;
			// set the the multiline property to be true; so we can have multiple lines in it
			text.multiline = false;
			// true so that line wrap at words end (at white characters)
			text.wordWrap = false;
			// the key to whether the font will be embedded (true) or not (false) in the swf
			text.embedFonts = true;
			text.selectable = false;
			// apply the text format to the text; this only works if you're not using the stylesheet property of the textfield
			// also, using defaultTextFormat property instead using setTextFormat method seems to work better; i couldn't find a reason for that, all i can think of, is that when setting the defaultTextFormat property, it takes only the values that are NOT NULL from the text format, and when using setTextFormat method, it sets all the values even if they are NULL; anyway, not even the old way, a combination of getTextFormat, setting the values needed, and setTextFormat, doesn't work anymore
			text.defaultTextFormat = textFormat;
			// set some text to see our text field; htmlText also works
			text.text = str;
			// set position of the text field
			text.y = bar_height / 3;
			
			// Add the text field in the display list of our document
			btn.addChild(text);
			
			if (icon) {
				var iconSprite:Sprite = new icon();
				
				var iconHeight:Number = Math.min(iconSprite.height, bar.height - 4);
				iconSprite.width *= iconHeight / iconSprite.height;
				iconSprite.height = iconHeight;
				
				text.x = iconSprite.x + iconSprite.width + 3;
				iconSprite.y = (bar.height - iconSprite.height) / 2;
				
				btn.addChild(iconSprite);
			}
			
			var prevBtn:DisplayObject = this.getChildByName("btn" + (num-1));
			if (align == "left") {
				if (!prevBtn) {
					btn.x = 10;
				} else {
					btn.x = prevBtn.x + prevBtn.width + 8;
				}
				leftButtons.push(btn);
			} else {
				if (!prevBtn) {
					btn.x = bar.width - btn.width - 10;
				} else {
					btn.x = prevBtn.x - btn.width - 8;
				}
				rightButtons.push(btn);
			}
			
			btn.addEventListener(MouseEvent.CLICK, onClick);
			btn.addEventListener(MouseEvent.MOUSE_OVER, onOver);
			btn.addEventListener(MouseEvent.MOUSE_OUT, onOff);
		}
		
		private function onClick(e:MouseEvent):void {
			var num:int = parseInt(e.target.name.substr(3));
			var str:String = String(xml.links.link[num-1]);
			obj.topNavClick(str);
		}
		
		private function onOver(e:MouseEvent):void {
			e.target.transform.colorTransform = ctOn;
		}
		
		private function onOff(e:MouseEvent):void {
			e.target.transform.colorTransform = ctOff;
		}
		
		public function resizeBotNav(width:Number, yPos:Number):void {
			bar.width = width;
			y = yPos;
			
			if (rightButtons.length == 0) { return; }
			
			// Move the right buttons over.
			var num:int = 0;
			var btn:Sprite;
			var prevBtn:Sprite;
			while (num < rightButtons.length) {
				btn = rightButtons[num];
				if(!prevBtn){
					btn.x = bar.width - btn.width - 10;
				} else {
					btn.x = prevBtn.x - btn.width - 8;
				}
				num++;
				prevBtn = btn;
			}
		}
	}
}