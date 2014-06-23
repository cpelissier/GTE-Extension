package lse.math.games.builder.presenter
{
	import flash.display.BitmapData;
	import flash.display.DisplayObjectContainer;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Rectangle;
	import flash.utils.ByteArray;
	import flash.geom.Point;
	
	import lse.math.games.builder.fig.CanvasToFigWriter;
	import lse.math.games.builder.io.FileManager;
	import lse.math.games.builder.io.OldExtensiveFormXMLWriter;
	import lse.math.games.builder.io.XMLExporter;
	import lse.math.games.builder.io.XMLImporter;
	import lse.math.games.builder.model.Iset;
	import lse.math.games.builder.model.Node;
	import lse.math.games.builder.model.Player;
	import lse.math.games.builder.model.Rational;
	import lse.math.games.builder.model.StrategicForm;
	import lse.math.games.builder.model.Strategy;
	import lse.math.games.builder.view.Canvas;
	import lse.math.games.builder.viewmodel.TreeGrid;
	
	import mx.collections.ArrayCollection;
	import mx.events.CollectionEvent;
	import mx.events.CollectionEventKind;
	import mx.events.PropertyChangeEvent;
	import mx.graphics.codec.PNGEncoder;
	import mx.rpc.http.HTTPService;
	
	import util.EvCodes;
	import util.EventManager;
	import util.Log;

	
	//TODO: Document
	//TODO: Organise in order the functions and such
	public class Presenter
	{
		//Mode codes: these are the same than the button indexes in the mode toggle bar
		public static const TREE_MODE:int = 0;
		public static const MATRIX_MODE:int = 1;
		private var _currentState:int;
		
		private var _canvas:Canvas;
		private var _grid:TreeGrid;
		private var _matrix:StrategicForm;
		
		private var _actionHandler:ActionHandler;
		private var _fileManager:FileManager;  
		private var log:Log = Log.instance;
		private var dispatcher:EventManager = EventManager.instance;

		private var _getClickAction:Function = null;
		private var _gridData:ArrayCollection = new ArrayCollection();
		private var _isStrategicReduced:Boolean = true;

		/* <--- --- TREE ONLY VARS --- ---> */
		private var _getDataUpdateAction:Function = null;	

		/* This variable signals if the last action was zooming eihter by 
           by mouse wheel or buttons. If the last action was zooming than the auto adjust
           feature is disabled for that move */
		private var _lastActionZoom:Boolean =false;
		
		private var _controllGuiModeSF:Function=null;
		private var _controllGuiModeEF:Function=null;
		
		public function Presenter():void
		{
			_currentState = TREE_MODE;
			_gridData.addEventListener("collectionChange", onOutcomeEdit);
			//TODO: #32 Possibly?¿ Remove the listener when switching

			_fileManager = new FileManager(this);
			_actionHandler  = new ActionHandler(_fileManager);
		}
		
		/** Determine if the last Action was Zooming */
		public function get isLastActionZoom():Boolean {
			return _lastActionZoom;
		}
		
		/** Quick way to view if the presenter is in Tree (Extensive Form) mode */
		public function get treeMode():Boolean {
			return (_currentState == TREE_MODE);
		}
		
		/** Quick way to view if the presenter is in Matrix (Strategic Form) mode */
		public function get matrixMode():Boolean {
			return (_currentState == MATRIX_MODE);
		}
		
		/** 
		 * The code of the current state, or mode, of the presenter,
		 * which can be one of the following:
		 * 0 [TREE_MODE] -> The tree is the main source of data
		 * 1 [MATRIX_MODE] -> The matrix is the main source of data
		 */
		public function get currentState():int { return _currentState; }
		
		/** Current tree representation */
		//This should be overridden in MatrixController to generate a new tree
		//if it is not updated
		public function get grid():TreeGrid { return _grid; }
		public function set grid(value:TreeGrid):void {
			_grid = value;
		}
		
		/** Current matrix representation */
		public function get matrix():StrategicForm { return _matrix; }
		public function set matrix(value:StrategicForm):void {
			_matrix = value;
		}
		
		/** If the secondary model is updated */
		public function get secondaryUpdated():Boolean { 
			if(treeMode)
				return _matrix.isUpdated;
			else if(matrixMode)
				return _grid.isUpdated;
			else {
				log.add(Log.ERROR_THROW, "Fatal ERROR: The program is working in an unknown mode");
				return true;
			}				
		}
		public function set secondaryUpdated(value:Boolean):void {
			if(treeMode)
				_matrix.isUpdated = value;
			else if(matrixMode)
				_grid.isUpdated = value;
		}
		
		/** Current canvas the application is running */
		public function get canvas():Canvas { return _canvas; }
		public function set canvas(canvas:Canvas):void {
			if (canvas == null) {
				log.add(Log.ERROR_THROW, "Cannot assign a null canvas")
			}
			_canvas = canvas;
			_canvas.addEventListener(MouseEvent.MOUSE_WHEEL, mouseZoomHandle);
			invalidate(true, true, true);
		}
		
		/** Class managing files in this controller */
		public function get fileManager():FileManager { return _fileManager; }
		
		public function get player1Name():String {
			if(treeMode)
				return _grid.firstPlayer.name;
			else if(matrixMode)
				return _matrix.firstPlayer.name;
			else {
				log.add(Log.ERROR_THROW, "Fatal ERROR: The program is working in an unknown mode");
				return null;
			}
		}
		
		public function get player2Name():String {
			if(treeMode)
				return _grid.firstPlayer.nextPlayer.name;
			else if(matrixMode)
				return _matrix.firstPlayer.nextPlayer.name;
			else {
				log.add(Log.ERROR_THROW, "Fatal ERROR: The program is working in an unknown mode");
				return null;
			}
		}
		
		
		[Bindable]
		public function get getControllGuiModeEF():Function {	return _controllGuiModeEF; }
		public function set getControllGuiModeEF(value:Function):void {
			_controllGuiModeEF = value;
		}
		
		[Bindable]
		public function get getControllGuiModeSF():Function {	return _controllGuiModeSF; }
		public function set getControllGuiModeSF(value:Function):void {
			_controllGuiModeSF = value;
		}
		
		[Bindable]
		/** Action executed when clicking in the canvas */
		public function get getClickAction():Function {	return _getClickAction; }
		public function set getClickAction(value:Function):void {
			if(treeMode) {
				_getClickAction = value;
				removeSelected(false);
			} else if(matrixMode) 
				log.add(Log.ERROR_THROW, "Cannot assign a null canvas")
		}
		
		[Bindable]
		public function get getDataUpdateAction():Function { return _getDataUpdateAction; }
		public function set getDataUpdateAction(value:Function):void {_getDataUpdateAction = value;}
		
		/** If the strategic form is reduced. */
		public function set isStrategicReduced(value:Boolean):void {	
			if(value != matrix.isStrategicReduced) {
				matrix.isStrategicReduced = value;
				if(treeMode){
					secondaryUpdated = false;
				}
				invalidate(false, true, true);
			}
		}
		
		[Bindable]
		public function get outcomeData():ArrayCollection {			
			return _gridData;
		}
		
		public function set outcomeData(value:ArrayCollection):void {
			_gridData = value;
			invalidate(true, false, false);
		}
		
		[Bindable]
		/** 
		 * Selected terminal node [TREE_MODE] or (TODO) [MATRIX_MODE]'s
		 * ID which corresponds to the 'leaves' data grid selected cell 
		 */
		public function get selectedOutcome():int {
			if(treeMode)
				return grid.selectedNodeId;
			else if(matrixMode)
			{
				log.add(Log.ERROR_THROW, "This function has not been implemented yet");
				return -1;
			}
			
			return -1;
		}
		
		public function set selectedOutcome(nodeId:int):void {
			if(treeMode)
			{
				grid.selectedNodeId = nodeId;			
				invalidate(false, false, true);
			} else if(matrixMode)
				log.add(Log.ERROR_THROW, "This function has not been implemented yet");
		}
		
		//TODO: 3PL What to do with this?
		[Bindable]
		/** If the sum of all pair of payoffs is 0 */
		public function get isZeroSum():Boolean {			
			return grid.isZeroSum;
		}
		
		public function set isZeroSum(value:Boolean):void {			
			grid.isZeroSum = value;
			//TODO: reset the leaves			
		}
		
		public function get numIsets():int { return grid.numIsets; }
		public function get numNodes():int { return grid.numNodes; }
		
		
		
		/* <--- --- MODE CHANGE FUNCTIONS --- ---> */
		
		public function toggleTreeMode():void
		{
			if(_currentState != TREE_MODE)
			{
				_currentState = TREE_MODE;
				_matrix.isSecondary = true;
				_grid.isSecondary = false;
				invalidate(true, false, true);
				fileManager.switchMode();
				dispatcher.dispatchEvent(new Event(EvCodes.MODE_CHANGED));
				//TODO #32 do lots of things here, such as RESETTING actionhandler?
			}
		}
		
		public function toggleMatrixMode():void
		{
			if(_currentState != MATRIX_MODE)
			{
				_currentState = MATRIX_MODE;
				
				//The following changes the internal structure of the matrix from one loaded with 
				//sequences to another one without that data. Ideally //TODO: Unify the matrix data
				//that will avoid the necessity to use this line:
				(new XMLImporter((new XMLExporter().writeMatrix(_matrix)))).loadMatrix(_matrix);
				
				_matrix.isSecondary = false;
				_grid.isSecondary = true;
				invalidate(true, false, true);
				fileManager.switchMode();
				dispatcher.dispatchEvent(new Event(EvCodes.MODE_CHANGED));
				
				//TODO #32 do lots of things here
			}
		}
		
		public function setPlayerName(p:Player,n:String):void {
			p.name=n;
			invalidate(true, false, true);
			
		}
		
		/**
		 * In [TREE_MODE] re-generates a matrix from the treeGrid,
		 * in [MATRIX_MODE] re-generates a grid from the matrix,
		 * in both cases if there are changes pending
		 */
		public function forceUpdateSecondary():void
		{
			if(!secondaryUpdated)
			{
				if(treeMode) {
					_matrix.populateFromTree();
				} else if(matrixMode) {
					_grid.populateFromMatrix();
				}
				
				secondaryUpdated = true;
			}
		}
		
		
		
		/* <--- --- ZOOM CONTROLS --- ---> */
		
		//Zooms in or out when a MOUSE_WHEEL event is detected
		private function mouseZoomHandle(e:MouseEvent):void
		{
			if(e.type==MouseEvent.MOUSE_WHEEL)
			{
				if(e.delta>0)
					zoomIn();
				else if(e.delta<0)
					zoomOut();
			}
		}
		
		/** Sets zoom to 100% */
		private function resetZoom():void
		{
			//set zooming flag
			_lastActionZoom=true;
			_canvas.painter.scale = 1.0;
			grid.scale = 1.0;
			invalidate(false, true, true);
		}
		
		/** Zooms in by increasing the scale in 1.1 */
		public function zoomIn():void
		{
			//set zooming flag
			_lastActionZoom=true;
			var oldScale:Number = _canvas.painter.scale;
			var newScale:Number = oldScale * 1.1;
			if (oldScale < 1 && newScale > 1) {
				newScale = 1.0;
			}
			
			_canvas.painter.scale = newScale;
			grid.scale = newScale;
			invalidate(false, true, true);
		}
		
		/** Zooms out by dividing the scale in 1.1 */
		public function zoomOut():void
		{
			//set zooming flag
			_lastActionZoom=true;
			var oldScale:Number = _canvas.painter.scale;
			var newScale:Number = oldScale / 1.1;
			if (oldScale > 1 && newScale < 1) {
				newScale = 1.0;
			}
			_canvas.painter.scale = newScale;
			grid.scale = newScale;
			invalidate(false, true, true);
		}
		
		/** Adjusts zoom to show the tree optimally */
		public function zoomAdjust():void
		{
			//set zooming flag
			_lastActionZoom=true;
			var scroller:DisplayObjectContainer = _canvas.parent;
			
			var width:Number = _canvas.painter.drawWidth;
			var height:Number = _canvas.painter.drawHeight;
			
			var oldScale:Number = _canvas.painter.scale;
			var newScale:Number = oldScale;
			
			if(scroller.width > width && scroller.height > height)
			{
				//Zoom in
				newScale = oldScale * Math.min(scroller.width/width, scroller.height/height);
				if(newScale > 5)
				{
					log.add(Log.HINT, "The tree is still very small, try adding some nodes on it before auto fitting it :)");
					
					newScale = (oldScale < 1 ? 1 : oldScale);
				}
			}
			else if(scroller.width < width || scroller.height < height)
			{
				//Zoom out
				newScale = oldScale * Math.min(scroller.width/width, scroller.height/height);
			}
			
			_canvas.painter.scale = newScale;
			grid.scale = newScale;
			invalidate(false, true, true);
		}





		/* <--- --- FILE MANAGING --- --->*/
		
		/** Resets everything */
		public function clear():void
		{
			//set zooming flag
			_lastActionZoom=true;
			resetZoom();
			
			if(treeMode)
				_actionHandler.reset(_grid);
			else if(matrixMode)
				_actionHandler.reset(_matrix);
			_fileManager.clear();
			
			invalidate(true, true, true);
		}		
		
		/** Opens a dialog for selecting and opening a file in xml format */
		public function open():void
		{
			_fileManager.openFile();
		}
		
		/** Opens a dialog for saving the tree in xml format */
		public function save():void 
		{			
			_fileManager.saveXML(saveCurrentGameToXML());
		}
		
		/**
		 * Returns a XML file with the current game packaged in it
		 */
		public function saveCurrentGameToXML():XML {
			var xmlWriter:XMLExporter = new XMLExporter();
			if(treeMode)
				return xmlWriter.writeGame(_grid);
			else if(matrixMode)
				return xmlWriter.writeGame(_matrix);
			else {
				log.add(Log.ERROR_THROW, "Fatal ERROR: The program is working in an unknown mode");
				return null;
			}
		}	
		
		/**
		 * Opens a dialog for saving an image of the current canvas in .fig format
		 */
		public function fig():void
		{
			var out:CanvasToFigWriter = new CanvasToFigWriter();
			
			removeSelected(true);
			var figStr:String = out.paintFig(_canvas.painter, _canvas.width, _canvas.height);
			restoreSelected();
			
			_fileManager.saveFig(figStr);
		}
		
		
		/**
		 * Returns a rectangle which specifies the minimum drawing area. This avoids any extra white space around the game tree of matrix
		**/
		
		
		public function getCroppedImage(_canvas:Canvas,bd:BitmapData):Rectangle{
			var startx:int;
			var starty:int;
			var endx:int;
			var endy:int;
			var stop:Boolean;
			var x:int;
			var y:int;
			
			stop=false;
			for (x=0;x<_canvas.width;x++) {
				for (y=0;y<_canvas.height;y++) {
					var z:uint=bd.getPixel(x,y);
					if (bd.getPixel(x,y)!=16777215) {
						startx=x;
						stop=true;
						if (stop)
							break;
					}
				}
				if (stop)
					break;
			}
			
			stop=false;
			for (y=0;y<_canvas.height;y++) {
				for (x=0;x<_canvas.width;x++) {
					if (bd.getPixel(x,y)!=16777215) {
						starty=y;
						stop=true;
						if (stop)
							break;
					}
				}
				if (stop)
					break;
			}
			
			stop=false;
			for (x=_canvas.width-1;x>0;x--) {
				for (y=_canvas.height-1;y>0;y--) {
					if (bd.getPixel(x,y)!=16777215) {
						endx=x;
						stop=true;
						if (stop)
							break;
					}
				}
				if (stop)
					break;
			}
			
			stop=false;
			for (y=_canvas.height-1;y>0;y--) {
				for (x=_canvas.width-1;x>0;x--) {
					if (bd.getPixel(x,y)!=16777215) {
						endy=y;
						stop=true;
						if (stop)
							break;
					}
				}
				if (stop)
					break;
			}
			
			return new Rectangle(startx,starty,endx-startx+1,endy-starty+1);
		}
		
		
		/**
		 * Opens a dialog for saving an image of the current canvas in .png format
		 */
		public function image():void
		{
				
			var bd:BitmapData = new BitmapData(_canvas.width, _canvas.height);
			
	
			removeSelected(true);
			_canvas.validateNow();
			bd.draw(_canvas);
			restoreSelected();
			
			var rec:Rectangle=getCroppedImage(_canvas,bd);		
			
			
			var small_bd:BitmapData = new BitmapData(rec.width, rec.height, false, 0x000000FF);
					
			small_bd.copyPixels(bd, rec, new Point(0, 0));
			
			
			var ba:ByteArray = (new PNGEncoder()).encode(small_bd);
			
			_fileManager.saveImage(ba);
		}
		
		/** Loads a tree/matrix from xml, deleting any previous states */
		public function loadFromXML(xml:XML):void
		{			
			
			var type:int = new XMLImporter(xml).type;
			if(type == XMLImporter.EF) {
				
				loadTreeFromXML(xml);
				_controllGuiModeEF();
			} else if(type == XMLImporter.SF) {
				
				loadMatrixFromXML(xml);
				_controllGuiModeSF();
			} else
			{
				log.add(Log.ERROR, "The file contained an unknown game format" +
					" and couldn't be loaded");
				return;
			}
			
			invalidate(true, true, true);
		}
		
		//Loads a tree from a XML file
		private function loadTreeFromXML(xml:XML):void {
			//TODO #32 This must switch presenters with the new data
			toggleTreeMode();
			_actionHandler.load(xml, grid);
			isZeroSum = false;	
		}
				
		private function loadMatrixFromXML(xml:XML):void {
			//TODO #32 actionhandler
			toggleMatrixMode();
			log.add(Log.HINT, "Loading matrix");
			(new XMLImporter(xml)).loadMatrix(_matrix);
		}
		
		
		
		/* <--- --- RUNNING SOLVER ALGORITHMS --- ---> */
		
		// URL Request Handler below here...
		public function runAlgorithm(algo:Object, seed:String):void
		{			
			forceUpdateSecondary();
			if (algo == null || algo.service == null || algo.service == undefined 
				|| algo.url == null || algo.url == undefined) {
				log.add(Log.ERROR, "Algorithm not configured");
				return;
			}
			
			var srv:HTTPService = HTTPService(algo.service);
			srv.url = algo.url;
			var params:Object = {
				algo: algo.uid				
			};
			if (seed != null) {
				params.s = seed;				
			}
			
			
			if (algo.type == "nf") {
				var rows:Vector.<Strategy> = _matrix.strategies(_matrix.firstPlayer);
				var cols:Vector.<Strategy> = _matrix.strategies(_matrix.firstPlayer.nextPlayer);
				params.a = getMatrixParam(_matrix.payMatrixMap[_matrix.firstPlayer], rows, cols);				
				params.b = getMatrixParam(_matrix.payMatrixMap[_matrix.firstPlayer.nextPlayer], rows, cols);
				params.r = getStrategyNamesParam(rows);
				params.c = getStrategyNamesParam(cols);
				
			} else if (algo.type == "xf") {				
				params.g = getTreeParam();
			} else {
				log.add(Log.ERROR, "type was not recognized: " + algo.type);
			}
			params.d=algo.dir;
			params.bw=algo.bw;
			params.bl=algo.bl;
			if ((algo.es==null) || (algo.es=="")) {
				params.es="0";
			} else {
				params.es=algo.es;
			}
			if ((algo.ms==null) || (algo.ms=="")) {
				params.ms="120";
			} else {
				params.ms=algo.ms;
			}
			
			srv.send(params);
		}
		
		private function getTreeParam():String
		{
			var xmlWriter:OldExtensiveFormXMLWriter = new OldExtensiveFormXMLWriter();
			var treeXML:XML = xmlWriter.write(grid);
			XML.prettyPrinting = false;
			var value:String = treeXML.toXMLString();
			XML.prettyPrinting = true;
			trace(value);
			return value;
		}
		
		//Returns a String table containing the matrix of payoffs of a player 
		private function getMatrixParam(payMap:Object, rows:Vector.<Strategy>, cols:Vector.<Strategy>):String
		{
			var lines:Vector.<String> = new Vector.<String>();
			for each (var row:Strategy in rows) 
			{				
				var line:Vector.<String> = new Vector.<String>();	
				for each (var col:Strategy in cols) 
				{					
					var pairKey:String = Strategy.key([row, col]);							
					line.push(payMap[pairKey]);
				}
				lines.push(line.join(" "));
			}			
			return lines.join("\r\n");
		}
		
		private function getStrategyNamesParam(strats:Vector.<Strategy>):String
		{
			var line:Vector.<String> = new Vector.<String>();
			for each (var strat:Strategy in strats) {				
				line.push(strat.getNameOrSeq(true));
			}			
			
			return line.join(" ");
		}		
		
		
		
		/* <--- --- ACTION HANDLING --- ---> */
		
		/** Restores the game to the state before applying the last action */
		public function undo():void
		{             
			if (_actionHandler.undo(grid)) {
				invalidate(true, true, true);
			} else {
				log.add(Log.HINT, "No more operations to undo");
			}
		}
		
		/** Restores the game to the state before undoing the last just undone action */
		public function redo():void
		{             
			if (_actionHandler.redo(grid)) {
				invalidate(true, true, true);
			} else {
				log.add(Log.HINT, "No more operations to redo");
			}
		}	
		
		/** 
		 * Creates an action from the 'getAction' function passed as parameter
		 *  Then it executes the action and invalidates whatever is necessary.
		 */
		public function doAction(getAction:Function):void
		{     
			//reset zooming flag
			_lastActionZoom=false;
			if ((treeMode)) {
				var action:IAction = getAction(grid);
				if (action != null) {
					_actionHandler.processAction(action, grid);						
					invalidate(action.changesData, action.changesSize, action.changesDisplay);
				}
			} else if(matrixMode) {
								
				//log.add(Log.ERROR_THROW, "This function has not been implemented yet");
			}
		}

		/**
		 * Creates an action from the 'getClickAction' function property, and the x and y coords passed as arguments
		 * <br>Then it executes the action and invalidates whatever is necessary.
		 * <br>It also deselects anything selected that could be selected, but Isets
		 */
		public function doActionAt(x:Number, y:Number):void
		{
			//reset zooming flag
			
			_lastActionZoom=false;
			if(treeMode) {
				if(getClickAction!= null)
				{
					selectedOutcome = -1;
					var action:IAction = getClickAction(grid, x, y);
					if (action != null) {
						_actionHandler.processAction(action, grid);									
						invalidate(action.changesData, action.changesSize, action.changesDisplay);
					}
				}
			} else if(matrixMode) {
				log.add(Log.ERROR_THROW, "This function has not been implemented yet");
			}
		}	
		
		public function doActionAtWithPlayer(x:Number, y:Number,player:Player):void
		{
			//reset zooming flag
			_lastActionZoom=false;
			if(treeMode) {
				if(getClickAction!= null)
				{
					selectedOutcome = -1;
					var action:IAction = getClickAction(grid, x, y,player);
					if (action != null) {
						_actionHandler.processAction(action, grid);									
						invalidate(action.changesData, action.changesSize, action.changesDisplay);
					}
				}
			} else if(matrixMode) {
				log.add(Log.ERROR_THROW, "This function has not been implemented yet");
			}
		}	
		
		/* <--- --- DISPLAY --- ---> */
		
		/** Invalidates display characteristics that need to be redrawn */
		public function invalidate(model:Boolean, canvasSize:Boolean, display:Boolean):void 
		{
			if (model) {
				secondaryUpdated = false;
				if(treeMode)
					updateSequenceTable();	
			}
			if (display) {
				// TODO: I'm updating labels twice when I switch forms
				_canvas.updateLabels(); // will trigger invalidateProperties();
			}
			if (canvasSize) {
				_canvas.invalidateSize();
			}
			if (display) {				
				_canvas.invalidateDisplayList();
			}	
		}
		
		private var _modelDirty:Boolean = true;
		private function updateSequenceTable():void
		{			
			if(treeMode) {		
				if (_modelDirty) {
					var dataIdx:int = 0;
					
					_modelDirty = false;
					for (var leaf:Node = grid.root.firstLeaf; leaf != null; leaf = leaf.nextLeaf) 
					{									
						var leafObj:Object = null;
						var update:Boolean = false;
						// while the current object isn't equal to and is left of the new leaf
						while (true) {
							leafObj = _gridData.length > dataIdx ? _gridData.getItemAt(dataIdx) : null;
							if (leafObj == null) {						
								break;
							} else if (leafObj.uid == leaf.number) {							
								if (areLeafChanges(leafObj, leaf)) {
									update = true;
								}	
								break;						
							} else if (grid.getNodeById(leafObj.uid) != null && grid.getNodeById(leafObj.uid).isRightOf(leaf)) {					
								leafObj = null;
								break;
							} else {					
								_gridData.removeItemAt(dataIdx);							
							}
						} 
						
						if (leafObj == null) 
						{
							leafObj = {
								uid: leaf.number		
							};
							if (_gridData.length <= dataIdx) {
								_gridData.addItem(leafObj);
							} else {
								_gridData.setItemAt(leafObj, dataIdx);
							}
						}
						
						leafObj.leaf = pathInString(leaf);				
						if (leaf.outcome != null) {
							var pay1:Rational = leaf.outcome.pay(grid.firstPlayer);
							var pay2:Rational = leaf.outcome.pay(grid.firstPlayer.nextPlayer);					
							leafObj.pay1 = pay1.isNaN ? "?" : pay1.toString();
							leafObj.pay2 = pay2.isNaN ? "?" : pay2.toString();
						} else {
							leafObj.pay1 = "?";
							leafObj.pay2 = "?";
						}
						if (update) {
							_gridData.itemUpdated(leafObj);
						}					
						++dataIdx;
					}
					invalidate(false, true, true);
					_modelDirty = true;				
				}
			} else if(matrixMode)
				log.add(Log.ERROR, "This function shouldn't be called from SF Edit Mode");
		}
		
		private var lastSelectedNode:int = -1;
		private var lastMergeBase:Iset = null;
		
		/* Removes the node and or iset currently selected [TREE_MODE] or
		 * (TODO) [MATRIX_MODE]. If keepCopy is true, values are kept 
		 * before removing them, for later restoration using restoreSelected() */
		private function removeSelected(keepCopy : Boolean):void
		{
			if(treeMode) {
				var invalidateDisplay:Boolean = false;
				if (selectedOutcome >= 0) {
					if(keepCopy)
						lastSelectedNode = selectedOutcome;
					
					selectedOutcome = -1;
					invalidateDisplay = true;
				}
				if (grid.mergeBase != null) {	
					if(keepCopy)
						lastMergeBase = grid.mergeBase;
					
					grid.mergeBase = null;
					invalidateDisplay = true;				
				}
				invalidate(false, false, invalidateDisplay);
			} else if(matrixMode){
				//TODO #32
			}
		}
		
		/* Restores last selected node and or Iset [TREE_MODE] or
		 * (TODO) [MATRIX_MODE], removed using removeSelected() function */
		private function restoreSelected():void
		{
			if(treeMode)
			{
				var invalidateDisplay:Boolean = false;
				if(lastSelectedNode != -1)
				{
					selectedOutcome = lastSelectedNode;
					lastSelectedNode = -1;
					invalidateDisplay = true;
				}
				if(lastMergeBase != null)
				{
					grid.mergeBase = lastMergeBase;
					lastMergeBase = null;
					invalidateDisplay = true;
				}
				invalidate(false, false, invalidateDisplay);
			} else if (matrixMode){
				//TODO #32
			}
		}
		
		
		
		/* <--- --- OTHER FUNCTIONS --- ---> */
		
		//When the values in the table at the right hand side get changed, this method is executed, 
		//which creates and processes a series of actions depending on the things modified
		private function onOutcomeEdit(event:CollectionEvent):void
		{
			if(treeMode) {
				if (event.kind == CollectionEventKind.UPDATE && _modelDirty) {
					var chain:ActionChain = null;
					for each (var pevent:PropertyChangeEvent in event.items) {	
						//TODO: #32 A new getDataUpdateAction needs to be created for NF mdoe
						var action:IAction = getDataUpdateAction(grid, pevent.source.uid, pevent.source.leaf, pevent.source.pay1, pevent.source.pay2);
						if (action != null) {
							if (chain == null) {
								chain = new ActionChain();
							}
							chain.push(action);
						}
					}
					if (chain != null) {
						_actionHandler.processAction(chain, grid);						
						invalidate(chain.changesData, chain.changesSize, chain.changesDisplay);		
					}
				}
			} else if(matrixMode)
				log.add(Log.ERROR_THROW, "This function has not been implemented yet");
		}
		
		//Settings.controller must look at
		
		//MatrixController must have rotate action or it shouldn't be an action
		
		//Handle click on canvas function in main should vary its behaviour depending on the canvas and controller
		
		//This with actions.randomPayoffs
		
		//getdataupdateaction mirar
									
		//Mirar getclickaction en treegridpres y getclickcallback en main
		
		//mirar isStrategicReduced -> Puede ser mejor mandarlo a nf por ejemplo
		
		//outcomeData -> si hay que cambiar mucho en matrixcontroller, mejor tomarlo del arbol generado y punto
		
		
		/* <--- --- TREE UNIQUE FUNCTIONS --- ---> */
		
		private function areLeafChanges(viewObj:Object, modelObj:Node):Boolean
		{
			var changes:Boolean = false;
			if (viewObj.leaf != pathInString(modelObj)) {				
				changes = true;
			}
			if (modelObj.outcome != null) {
				var pay1:Rational = modelObj.outcome.pay(grid.firstPlayer);
				var pay2:Rational = modelObj.outcome.pay(grid.firstPlayer.nextPlayer);					
				if ((pay1.isNaN && viewObj.pay1 != "?") || 
					(!pay1.isNaN && viewObj.pay1 != pay1.toString()))
				{
					changes = true;
				}
				if ((pay2.isNaN && viewObj.pay2 != "?") || 
					(!pay2.isNaN && viewObj.pay2 != pay2.toString()))
				{
					changes = true;
				}
			} else if (viewObj.pay1 != "?" || viewObj.pay2 != "?") {
				changes = true;			
			}
			return changes;
		}
		
		private function pathInString(node:Node):String
		{
			var rv:Vector.<String> = new Vector.<String>();
			var n:Node = node;
			while (n.reachedby != null)
			{
				rv.push(n.reachedby);
				n = n.parent;
			}
			rv.reverse();
			return rv.join(" ");
		}
		
	}
}