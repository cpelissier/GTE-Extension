package lse.math.games.builder.io 
{	
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	
	import lse.math.games.builder.model.ExtensiveForm;
	import lse.math.games.builder.model.Game;
	import lse.math.games.builder.model.Iset;
	import lse.math.games.builder.model.Node;
	import lse.math.games.builder.model.Player;
	import lse.math.games.builder.model.StrategicForm;
	import lse.math.games.builder.model.Strategy;
	import lse.math.games.builder.settings.FileSettings;
	import lse.math.games.builder.settings.SCodes;
	import lse.math.games.builder.viewmodel.TreeGrid;
	
	import mx.utils.HexEncoder;
	
	import util.Log;
	
	/**	 
	 * XMLImporter saves trees and matrixes from XML data. <p/>
	 * 
	 * Instructions to use it:<br/>
	 * Just call writeTree or writeMatrix (depending on what you want to save)
	 * 
	 * @author Mark Egesdal & alfongj
	 */
	//TODO: Do something with gameDescription info
	//TODO: In the future, write node and iset names & maybe? payoffs in non-outcomes
	public class XMLExporter
	{			
		private var VERSION:Number = 0.3;
		
		private var log:Log = Log.instance;
		
		
		
		/** Exports a game into its format, automatically checking its type */
		public function writeGame(game:Game):XML
		{
			if(game is ExtensiveForm)
				return writeTree(game as ExtensiveForm);
			else if(game is StrategicForm)
				//return writeMatrix(game as StrategicForm);
				  return exportSampleGame();
			else {
				log.add(Log.ERROR_THROW, "Tried to save a game with no form");
				return null;
			}
		}
		
		/* <--- --- DISPLAY EXPORTING --- --->*/
		
		//Writes the settings as children of a parent XMLList (which should be <display>)
		private function writeDispSettings(parent:XMLList, isEF:Boolean):void //TODO: St form settings
		{
			var fileSettings:FileSettings = FileSettings.instance;
			
			var setting:XML;
			
			//Player colors //TODO: 3PL
			setting = <color />
			setting.@player = "1";
			setting.appendChild(hexStr(fileSettings.getValue(SCodes.FILE_PLAYER_1_COLOR) as uint));
			parent.appendChild(setting);
			
			setting = <color />
			setting.@player = "2";
			setting.appendChild(hexStr(fileSettings.getValue(SCodes.FILE_PLAYER_2_COLOR) as uint));
			parent.appendChild(setting);
			
			//CMP
			setting = <color />
			setting.@player = "3";
			setting.appendChild(hexStr(fileSettings.getValue(SCodes.FILE_PLAYER_3_COLOR) as uint));
			parent.appendChild(setting);
			
			setting = <font />
			setting.appendChild(fileSettings.getValue(SCodes.FILE_FONT) as String);
			parent.appendChild(setting);
			
			setting = <strokeWidth />
			setting.appendChild(fileSettings.getValue(SCodes.FILE_STROKE_WIDTH) as int);
			parent.appendChild(setting);
			
			if(isEF)
			{
				setting = <nodeDiameter />
				setting.appendChild(fileSettings.getValue(SCodes.FILE_NODE_DIAMETER) as Number);
				parent.appendChild(setting);
				
				setting = <isetDiameter />
				setting.appendChild(fileSettings.getValue(SCodes.FILE_ISET_DIAMETER) as Number);
				parent.appendChild(setting);
				
				setting = <levelDistance />
				setting.appendChild(fileSettings.getValue(SCodes.FILE_LEVEL_DISTANCE) as int);
				parent.appendChild(setting);
			} else {
				setting = <cellVertPadding />
				setting.appendChild(fileSettings.getValue(SCodes.FILE_CELL_PADDING_VERT) as Number);
				parent.appendChild(setting);
				
				setting = <cellHorizPadding />
				setting.appendChild(fileSettings.getValue(SCodes.FILE_CELL_PADDING_HOR) as Number);
				parent.appendChild(setting);
			}
		}
		
		//Returns a String with the Hex value of a color in the format: #RRGGBB 
		private function hexStr(color:uint):String
		{
			var h:HexEncoder = new HexEncoder(); 
			var ba:ByteArray = new ByteArray();
			ba.writeUnsignedInt(color);
			h.encode(ba);
			return "#" + h.flush().substring(2);			
		}
		
		
		
		/* <--- --- PLAYERS EXPORTING --- ---> */
		
		//Writes the players as elements of a parent XMLList (which should be <players>)
		//NOTE: This is 3PL+ prepared
		private function writePlayers(parent:XMLList, firstPlayer:Player, numPlayers:int):void
		{
			var player:Player = firstPlayer;
			for(var i:int = 1; i<=numPlayers; i++)
			{
				var playerNode:XML = <player />;
				playerNode.@playerId = ""+i;
				playerNode.appendChild(player.name);
				parent.appendChild(playerNode);
				
				player = player.nextPlayer;
			}
		}
		

		
		/* <--- --- TREE EXPORTING --- --->*/
		
		/** Writes an ExtensiveForm tree into the latest xml format representation */
		public function writeTree(tree:ExtensiveForm):XML
		{
			//TODO: This is ugly, move functions to ExtForm or write TreeGrids
			if((tree is TreeGrid) && !(tree as TreeGrid).isUpdated)
				(tree as TreeGrid).populateFromMatrix();
			
			var xml:XML = 
				<gte>
					<gameDescription/>
					<display/>
					<players/>
					<extensiveForm/>				
				</gte>;
			
			xml.@version = VERSION;
			
			writeDispSettings(xml.display, true);
			writePlayers(xml.players, tree.firstPlayer, tree.numPlayers);
			
			xml.extensiveForm.appendChild(getNodeElem(tree.root, tree));						
			
			return xml;
		}
		

		
		//Returns an xml subtree of the original tree, starting from the node 'n',
		//including all valuable model info: nodes with their attributes (isets and
		//players), outcomes with payoffs
		private function getNodeElem(n:Node, tree:ExtensiveForm):XML
		{
			var nodeElem:XML;			
			if (!n.isLeaf) {
				nodeElem = <node />;
				
				//Add iset attributes
				if (n.iset != null)
				{ 
					if(n.iset.numNodes > 1) 
						nodeElem.@iset = n.iset.idx;
					
					if (n.iset.player != Player.CHANCE) {
						nodeElem.@player = n.iset.player.name;
					}
				}
				
				for (var child:Node = n.firstChild; child != null; child = child.sibling) {
					nodeElem.appendChild(getNodeElem(child, tree));
				}
			} else {
				nodeElem = <outcome />;
				
				//Add iset attributes
				if (n.iset != null)
				{ 
					if(n.iset.numNodes > 1) 
						nodeElem.@iset = n.iset.idx;
					
					if (n.iset.player != Player.CHANCE) {
						nodeElem.@player = n.iset.player.name;
					}
				}
				
				if(n.outcome != null)
					for (var player:Player = tree.firstPlayer; player != null; player = player.nextPlayer) 
					{
						var payoffElem:XML = <payoff/>;
						payoffElem.@player = player.name;
						payoffElem.appendChild(n.outcome.pay(player).toString());					
						nodeElem.appendChild(payoffElem);
					}
			}
			
			//Add moves
			if (n.reachedby != null)
			{ 
				if(n.parent.iset.player == Player.CHANCE) {
				nodeElem.@prob = n.reachedby.label;
			} else  {
				nodeElem.@move = n.reachedby.label; // TODO: add a unique constraint in the program to prevent errors here?
				}
			}
			
			return nodeElem;
		}
		
		
		
		/* <--- --- MATRIX EXPORTING --- --->*/
		
		/** Writes an ExtensiveForm tree into the latest xml format representation */
		public function writeMatrix(matrix:StrategicForm):XML
		{
			//TODO: Currently the matrix is exported as is in the moment of exporting: reduced or not
			//warn the user about that, keep two buttons, or decide to export always in one way
			if(!matrix.isUpdated)
				matrix.populateFromTree()
			
			var xml:XML = 
				<gte>
					<gameDescription/>
					<display/>
					<players/>
					<strategicForm/>				
				</gte>;
			
			xml.@version = VERSION;
			
			writeDispSettings(xml.display, false);
			writePlayers(xml.players, matrix.firstPlayer, matrix.numPlayers);
			
			writeSizeAndStrategies(xml.strategicForm, matrix);
			
			return xml;
		}
		
		//CMP: Temporary function. Exports the default game in the strategic view to an XML file. 
		public function exportSampleGame(): XML
		{
			
			//This is the sample 2x2x3 game shown by default in the Strategic Form view. TODO: Implement functionality to internally represent 3-player games and convert between
			//extensive and strategic form. 
			var pl1NumStr:int = 2;
			var	pl2NumStr:int = 2;
			var	pl3NumStr:int = 3;
			
			var pl1PayMapStr:String = "1 2\n0 4//3 5\n7 9//11 12\n13 14";
			var pl2PayMapStr:String = "3 0\n0 1//4 6\n8 10//15 16\n17 18";
			var	pl3PayMapStr:String = "5 6\n4 3//4 3\n2 1//19 20\n21 22";
			
			var xml:XML = 
				<gte>
					<gameDescription/>
					<display/>
					<players/>
					<strategicForm/>				
				</gte>;
			
			xml.@version = VERSION;
			
			//Write display settings
			writeDispSettings(xml.display, false);
			
			//This mimics the for loop where player names are looped over
			var playerNode1:XML = <player />;
			playerNode1.@playerId = "1";
			playerNode1.appendChild("I");
			xml.players.appendChild(playerNode1);
			
			var playerNode2:XML = <player />;
			playerNode2.@playerId = "2";
			playerNode2.appendChild("II");
			xml.players.appendChild(playerNode2);
			
			var playerNode3:XML = <player />;
			playerNode3.@playerId = "3";
			playerNode3.appendChild("III");
			xml.players.appendChild(playerNode3);
			
			//Write the size attribute by looking at the number of strategies each player has
			var sizeAttribute:String = "{ " + pl1NumStr + " " + pl2NumStr + " " + pl3NumStr + " }" ;
			xml.strategicForm.@size = sizeAttribute; 
			
			//Write the strategies of each player. Note that these are hardcoded here, though they are generated dynamically by the Autolabeller in MatrixEditor.mxml. 
			var child1:XML = <strategy/>; 
			child1.@player = "1";
			var childContent1:String = "{ \"A\" \"B\" }"
			child1.appendChild(childContent1);
			xml.strategicForm.appendChild(child1);
			
			var child2:XML = <strategy/>; 
			child2.@player = "2";
			var childContent2:String = "{ \"a\" \"b\" }"
			child2.appendChild(childContent2);
			xml.strategicForm.appendChild(child2);
			
			var child3:XML = <strategy/>; 
			child3.@player = "3";
			var childContent3:String = "{ \"C\" \"D\" \"E\" }"
			child3.appendChild(childContent3);
			xml.strategicForm.appendChild(child3);
			
			//Parse payoffs and write to XML
			
			var panel_text_p1:Array = pl1PayMapStr.split("//");
			var panel_text_p2:Array = pl2PayMapStr.split("//");
			var panel_text_p3:Array = pl3PayMapStr.split("//");
			
			
			var contents:String = "";
			
			//Format: Payoffs are written as follows: P1's strategies are iterated over first (the most internal loop), followed by P2's strategies, followed by
			//P3's strategies. In this way, P1's strategy changes every iteration, P2's strategy changes every @pl1NumStr iterations, and P3's strategy changes
			//every @pl2NumStr * @pl1NumStr iterations. Payoffs are comma separated in the format P1,P2,P3, and each new payoff tuple is separated by a newline. 
			
			//loop over panels
			for (var panel:int =0; panel < pl3NumStr; panel++)
			{
				var p1Rows:Array = panel_text_p1[panel].split("\n");
				var p2Rows:Array = panel_text_p2[panel].split("\n");
				var p3Rows:Array = panel_text_p3[panel].split("\n");
				//loop over rows
				for(var row:int =0; row < pl2NumStr; row++)
				{
					var p1Columns:Array = p1Rows[row].split(" ");
					var p2Columns:Array = p2Rows[row].split(" ");
					var p3Columns:Array = p3Rows[row].split(" ");
					//loop over columns
					for(var column:int =0; column < pl1NumStr; column++)
					{
						contents += p1Columns[column] + "," + p2Columns[column] + "," + p3Columns[column];
						contents += "\n";
					}
					
				}
			}
			
			var child:XML = <payoffs/>;
			child.appendChild(contents);
			
			xml.strategicForm.appendChild(child);
			
			return xml;
			
		}
		
		
		// Write each players' strategies and the size attribute 
		private function writeSizeAndStrategies(parent:XMLList, matrix:StrategicForm):void
		{			
			var strategies:Array = new Array();
			
			//Write <strategy> elements
			var player:Player = matrix.firstPlayer;
			for(var i:int=0; i<matrix.numPlayers; i++)
			{
				var plStrategies:Vector.<Strategy> = matrix.strategies(player);
				var child:XML = <strategy/>;
				
				//Set the player attribute
				//CMP: Label players by id instead of name
				child.@player = player.id;
				
				//Set the content with the name of each strategy
				var childContent:String = "{ ";
				for each(var s:Strategy in plStrategies)
					childContent += ("\"" + s.getNameOrSeq() + "\" ");
				childContent += "}";
				child.appendChild(childContent);
				
				strategies[i] = plStrategies;
				
				parent.appendChild(child);
				player = player.nextPlayer;
			}
			
			//Write size attribute
			var sizeAttribute:String = "{ ";
			for (i = 0; i<strategies.length; i++)
				sizeAttribute += (strategies[i] as Vector.<Strategy>).length + " ";
			sizeAttribute += "}";
			trace("SIZE ATTRIBUTE"+  sizeAttribute);
			parent.@size = sizeAttribute;
			
			//Write payoff matrixes
			var payMap:Dictionary = matrix.payMatrixMap;
			
			player = matrix.firstPlayer;
			for( i = 0; i<matrix.numPlayers; i++)
			{
				child = <payoffs/>;
				child.@player = player.name;
				var plPayoffs:Object = payMap[player];
				
				var contents:String = "";
				
				var width:int = (strategies[0] as Vector.<Strategy>).length; //Num strat of 1st pl
				var height:int = 1; //The height is equal to multiplying the num of strat
									//of each player but the first one
				for(var j:int = 1; j<strategies.length; j++)
					height *= (strategies[j] as Vector.<Strategy>).length;
				
				for(j = 0; j<height; j++)
				{
					for(var k:int = 0; k<width; k++)
					{
						contents += plPayoffs[keyForCoords(j,k,strategies)];
						if(k!=width-1)
							contents += " ";
					}
					contents += "\n";
				}
				
				child.appendChild(contents);
				parent.appendChild(child);
				player = player.nextPlayer;
			}
		}
		
		/*
		 * Returns the key corresponding to certain coordinates for the pay matrix
		 * The 'v' coord is for vertical, 'h' for horizontal
		 * h corresponds to the first player's strategy
		 * v corresponds to a combo of the rest of the players strategies, multiplied in order
		 */
		private function keyForCoords(v:int, h:int, strategies:Array):String
		{
			var stCombo:Array = new Array();
			stCombo.push((strategies[0] as Vector.<Strategy>)[h]);
			
			var cumulativeProd:int = 1; 
			for(var i:int = 1; i<strategies.length; i++)
			{
				var vecStr:Vector.<Strategy> = strategies[i] as Vector.<Strategy>;
				var numSt:int = vecStr.length; 
				
				var strNumber:int = (v / cumulativeProd) % numSt;

				stCombo.push(vecStr[strNumber]);
				cumulativeProd *= numSt;
			}
			
			return Strategy.key(stCombo);
		}
		
	}
}