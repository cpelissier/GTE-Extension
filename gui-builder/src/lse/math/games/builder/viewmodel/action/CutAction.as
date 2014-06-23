package lse.math.games.builder.viewmodel.action 
{
	import flash.utils.getTimer;
	
	import lse.math.games.builder.model.Node;
	import lse.math.games.builder.presenter.IAction;
	import lse.math.games.builder.viewmodel.AutoLabeller;
	import lse.math.games.builder.viewmodel.TreeGrid;
	
	import util.Log;

	/**	
	 * Divides the iset of selected node into two parts, one on the left ending in the Iset, 
	 * another on the right with the rest of nodes
	 * <li>Changes Data</li>
	 * <li>Changes Size</li>
	 * <li>Changes Display</li>
	 * @author Mark Egesdal
	 */
	public class CutAction implements IAction
	{
		private var _nodeId:int = -1;
		private var log:Log = Log.instance;
		
		private var _timeElapsed:int = 0;
		
		
		
		public function get timeElapsed():int {return _timeElapsed; }
		
		public function CutAction(node:Node) 
		{
			if (node != null) _nodeId = node.number;
		}
		
		public function doAction(grid:TreeGrid):void
		{
			var prevTime:int = getTimer();
			
			var node:Node = grid.getNodeById(_nodeId);
			if (node != null) {
				node.makeLastInIset();	
				
				var labeler:AutoLabeller = new AutoLabeller;
				labeler.autoLabelTree(grid,false);
			} else
				log.add(Log.ERROR, "Couldn't find any node with idx "+_nodeId, "CutAction");
			
			grid.orderIds();
			
			_timeElapsed = getTimer() - prevTime;
		}
		
		public function get changesData():Boolean {
			return true;
		}
		
		public function get changesSize():Boolean {
			return true;
		}
		
		public function get changesDisplay():Boolean {
			return true;
		}
	}
}