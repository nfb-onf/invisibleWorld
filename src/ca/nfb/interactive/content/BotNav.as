package ca.nfb.interactive.content{
	
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.text.Font;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.utils.getDefinitionByName;
	
	public class BotNav extends BaseNFB {
		
		public static const BUTTON_PADDING:Number = 6;
		public static var bar_height:Number = 30;
		
		private var bar:Sprite;
		private var btn:Sprite;
		private var btnHash:Object;
		private var iconHash:Object;
		private var textFormat:TextFormat;
		private var xml:XML;
		private var obj:Object;
		private var activators:Object = {};
		
		private var leftButtons:Vector.<Sprite> = new Vector.<Sprite>();
		private var rightButtons:Vector.<Sprite> = new Vector.<Sprite>();
		private var leftDiv:Vector.<Sprite> = new Vector.<Sprite>();
		private var rightDiv:Vector.<Sprite> = new Vector.<Sprite>();
		
		public function BotNav(_obj:Object, _xml:XML, w:Number, yPos:Number, lang:String, useTouch:Boolean = false) {
			//add bar
			obj = _obj;
			xml = _xml;
			bar = new Sprite();
			btnHash = {};
			iconHash = {};
			addChild(bar);
			bar.graphics.beginFill(0x000000);
			bar.graphics.drawRect(0,0,30,bar_height);
			bar.graphics.endFill();
			bar.width=w;
			this.y=yPos;
						
			// we get a reference to the definition of the MyFont class (the class of our font created in the library)
			// we could have just used 'Standard0756' directly, but some editors, like FDT, complain about it, saying that the specified definition does not exist, and if we have errors, the editor will not give us code completion... correctly; 
			var MyFontClass:Class = (lang == "kh" ? getDefinitionByName("KhmerOS") : getDefinitionByName("Standard0756")) as Class;
			// create an instance of our font class
			var myFont : Font = new MyFontClass() as Font;
			
			// in order to specify what font we'll use for our textfield, we need a textformat object
			textFormat = new TextFormat();
			// set it's font property (String) to the name of our font
			// you might notice that we could have passed in the name of the font directly, hard coded; and it would have worked; but it's safer this way; fonts may have different names on different OSs, so when compiling the fla on a different OS, the font might not be found, thus the text will not be displayed; although you might argue that the font is there; also it's easier to change the font; only change it in library and recompile
			textFormat.font=myFont.fontName;
			// set font size
			textFormat.size=bar_height / 4;
			// set font tracking
			//textFormat.letterSpacing = 1;
			// set font color
			textFormat.color=0xffffff;
			
			//add links			
			var totalLinks:int = xml.links.link.length();
			var link:XML, btn:Sprite;
			var i:int, str:String, icon:String, side:String, activator:String;
			var rightCount:int = 0, leftCount:int = 0;
			
			if (useTouch) {
				// Create left-side spacing for Navigation.
				var label:String;
				if (lang == "fr") {
					label = "La Navigation";
				} else if (lang == "kh") {
					label = "ការបើកនាវារឺយន្ដហោហ";
				} else {
					label = "Navigation";
				}
				
				btn = createTextBtn(
					0,
					label,
					"left", 
					null,
					null
				);
			}
			
			for(i=1; i<=totalLinks; i++){
				link = xml.links.link[i-1];
				str = String(link);
				icon = link.@icon.toString();
				side = link.@side.toString();
				activator = link.@activator.toString();
				
				btn = createTextBtn(
					i,
					str,
					side, 
					icon ? getDefinitionByName(icon) as Class : null,
					activator
				);
				btnHash[link.@name.toString()] = btn;
			}
		}
		
		private function createTextBtn(num:int, str:String, align:String = "left", icon:Class = null, activator:String = null):Sprite {
			btn = new Sprite();
			addChild(btn);
			btn.name = "btn" + num;
			btn.buttonMode = true;
			btn.mouseChildren = false;
			btn.alpha = 0.4;
			// create the textField object
			var text : TextField = new TextField();
			text.name = "txt";
			// optionally set a name for the textfield, so we can refer to it, if we need to, later			
			// set the autosize option to "left"; using constants is more error proof
			text.autoSize=TextFieldAutoSize.LEFT;
			// set the the multiline property to be true; so we can have multiple lines in it
			text.multiline=false;
			// true so that line wrap at words end (at white characters)
			text.wordWrap=false;
			// the key to whether the font will be embedded (true) or not (false) in the swf
			text.embedFonts=true;
			text.selectable=false;
			// apply the text format to the text; this only works if you're not using the stylesheet property of the textfield
			// also, using defaultTextFormat property instead using setTextFormat method seems to work better; i couldn't find a reason for that, all i can think of, is that when setting the defaultTextFormat property, it takes only the values that are NOT NULL from the text format, and when using setTextFormat method, it sets all the values even if they are NULL; anyway, not even the old way, a combination of getTextFormat, setting the values needed, and setTextFormat, doesn't work anymore
			text.defaultTextFormat=textFormat;
			// set some text to see our text field; htmlText also works
			text.text = str.toUpperCase();
			// set position of the text field
			text.x = BUTTON_PADDING;
			text.y = bar_height / 3;
			
			// Add the text field in the display list of our document
			btn.addChild(text);
			
			if (icon) {
				var iconSprite:MovieClip = new icon();
				btn.addChild(iconSprite);
				iconSprite.gotoAndStop(0);
				text.x = iconSprite.x + iconSprite.width + 3 + BUTTON_PADDING;
				iconSprite.x = BUTTON_PADDING;
				iconSprite.y = (bar.height - iconSprite.height) / 2;
				iconHash[btn.name] = iconSprite;
			}
			
			if (activator) {
				if (!activators[activator]) {
					activators[activator] = [];
				}
				activators[activator].push(btn);
				btn.visible = false;
			}
			
			// Add backdrop to button so it can be clicked easier.
			btn.graphics.beginFill(0, 0);
			btn.graphics.drawRect(0, 0, btn.width + BUTTON_PADDING * 2, bar_height);
			
			var prevBtn:Sprite = this.getChildByName("btn" + (num-1)) as Sprite;
			var div:Div;
			if (align == "left") {
				if(!prevBtn){
					btn.x = 10;
				} else {
					div = new Div();
					addChild(div);
					div.y = 5;
					div.x = prevBtn.x + prevBtn.width;
					btn.x = prevBtn.x + prevBtn.width + div.width;
					leftDiv.push(div);
					div.visible = btn.visible;
				}
				leftButtons.push(btn);
			} else {
				if(!prevBtn){
					btn.x=bar.width - btn.width - 10;
				} else {
					div = new Div();
					addChild(div);
					div.y = 5;
					div.x = prevBtn.x - div.width;
					btn.x = prevBtn.x - btn.width - div.width;
					rightDiv.push(div);
					div.visible = btn.visible;
				}
				rightButtons.push(btn);
			}
			
			btn.addEventListener(MouseEvent.CLICK, onClick);
			btn.addEventListener(MouseEvent.MOUSE_OVER, onOver);
			btn.addEventListener(MouseEvent.MOUSE_OUT, onOff);
			
			return btn;
		}
		
		private function onClick(e:MouseEvent):void {
			var num:int = parseInt(e.target.name.substr(3));
			var str:String = String(xml.links.link[num-1]);
			obj.bottomNavClick(str);
		}
		
		private function onOver(e:MouseEvent):void {
			e.target.alpha = 1;
		}
		
		private function onOff(e:MouseEvent):void {
			e.target.alpha = 0.4;
		}
		
		public function setButtonActive(id:int, active:Boolean):void {
			var icon:MovieClip = iconHash["btn" + id];
			icon.gotoAndStop(active ? "on" : "off");
			
			var name:String = xml.links.link[id-1].@name;
			if (activators[name]) {
				var button:Sprite, buttons:Array = activators[name];
				for each (button in buttons) {
					button.visible = active;
				}
			}
			
			resizeBotNav(bar.width, y);
		}
		
		public function resizeBotNav(w:Number, yPos:Number):void {
			bar.width = w;
			this.y = yPos;
			
			if (rightButtons.length == 0) { return; }
			
			// Move the right buttons over.
			var num:int = 0;
			var btn:Sprite;
			var div:Sprite;
			var prevBtn:Sprite;
			while (num < rightButtons.length) {
				btn = rightButtons[num];
				if (!btn.visible) {
					rightDiv[num].visible = false;
					num++;
					continue;
				}
				
				if(!prevBtn){
					btn.x = bar.width - btn.width - 10;
				} else {
					btn.x = prevBtn.x - btn.width - 8;
				}
				
				if (rightDiv.length > num) { 
					rightDiv[num].x = btn.x - 5; 
				}
				
				prevBtn = btn;
				num++;
			}
		}
	}
}