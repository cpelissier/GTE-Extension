package util
{
	import flash.display.DisplayObject;
	import flash.events.KeyboardEvent;
	
	import spark.components.Label;
	import spark.components.TextInput;
	import spark.components.TextArea;
	import mx.core.FlexGlobals;
	
	import mx.managers.PopUpManager;
	
	import spark.components.VGroup;
	
	
	/**
	 * PopUp 'prompt' with text input creator, which contains a title, text and textbox. Only one pop up prompt can be shown at each time
	 * <br/>USAGE: <ol>
	 * <li>First, create inside the class from which you'll be calling Prompt.show(), a function you want it to call after closing the prompt</li>
	 * <li>Secondly, call Prompt.show() not forgetting to pass it a valid 'parent' DisplayObject from which to throw the popup</li>
	 * <li>Thirdly, in the function you created in step 1, pick up the result of the prompt via Prompt.lastEnteredText. 
	 * Don't forget to check if its null: that will mean that the user pressed the 'Cancel' button</li> 
	 * </ol>
	 * @author alfongj
	 */
	public class PromptTextInputCanvas
	{		
		private static var ti:TextInput;
		private static var ta:TextInput;
		private static var vg:VGroup;
		private static var mode:int;
		private static var _onReturn:Function;
		private static var _parent:DisplayObject = FlexGlobals.topLevelApplication as DisplayObject;
		
		public static var lastEnteredText:String; //String containing the result text of the prompt
		
		/**
		 * Throws a prompt in a pop up window
		 * @param parent: DisplayObject from which to throw the pop up
		 * @param onReturn: Function to execute after the user has pressed one of the buttons and closed the popup
		 * @param text: Text to show the user 
		 */
		public static function show(onReturn:Function, text:String, x:Number, y:Number,type:int,color:uint):void {
			vg=new VGroup();
			vg.x=x;
			vg.y=y;
			mode=type;
			
			if (mode==1) {
				ti=new TextInput();
				ti.text=text;
				ti.setStyle("focusSkin","null");
				ti.setStyle("focusColor","#aa0000"); 
				ti.addEventListener(KeyboardEvent.KEY_DOWN,keyPressedEnter);	
				ti.selectAll();
				vg.addElement(ti);
			} else if (mode==2) {
				ta=new TextInput();
				ta.height=20;
				ta.width=300;
				ta.setStyle("borderStyle","solid");
				ta.setStyle("borderColor",String(color));
				ta.text=text;
				ta.addEventListener(KeyboardEvent.KEY_DOWN,keyPressedEnter);	
				vg.addElement(ta);
				ta.selectAll();
				
			}
			
			var l:Label=new Label()
			l.text="Accept:Enter Cancel:Esc";
			l.setStyle("fontStyle","italic");
			l.setStyle("sontSize","8");
			l.setStyle("color","#505050");
			
			
			vg.addElement(l);
			_onReturn=onReturn;
			PopUpManager.addPopUp(vg, _parent, true);
			vg.invalidateDisplayList();
	
			if (mode==1) {
				ti.setFocus();
			} else if (mode==2) {
				ta.setFocus();
				PopUpManager.centerPopUp(vg);
			}
		}
		
		private static function keyPressedEnter(event:KeyboardEvent):void{
			
			if (event.keyCode==13){
				PopUpManager.removePopUp(vg);
				if (mode==1)
					lastEnteredText=ti.text;
				else if (mode==2)
					lastEnteredText=ta.text;
				_onReturn();
			} else if (event.keyCode==27){
				PopUpManager.removePopUp(vg);
				lastEnteredText=null;
				_onReturn();
			}
			
			//lastEnteredText = null;
		}
	
	}
}