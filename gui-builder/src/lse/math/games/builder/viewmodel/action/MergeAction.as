package lse.math.games.builder.viewmodel.action
{
	import flash.utils.getTimer;
	
	import lse.math.games.builder.model.Iset;
	import lse.math.games.builder.presenter.IAction;
	import lse.math.games.builder.viewmodel.TreeGrid;
	
	/**	
	 * Merges two Isets, if possible
	 * <li>Can change Data</li>
	 * <li>Can change Size</li>
	 * <li>Changes Display</li>
	 * @author Mark Egesdal
	 */
	public class MergeAction implements IAction
	{				
		private var _mergeId:int = -1;
		private var _baseId:int = -1;
		
		private var _onMerge:IAction;
		
		private var _timeElapsed:int = 0;
		
		
		
		public function get timeElapsed():int {return _timeElapsed; }
		
		public function MergeAction(grid:TreeGrid, toMerge:Iset) 
		{			
			if (toMerge != null) _mergeId = toMerge.idx;
			if (grid.mergeBase != null) {
				_baseId = grid.mergeBase.idx;			
				if (!grid.mergeBase.canMergeWith(toMerge)) {
					_mergeId = -1;
				}
			}
		}
		
		public function set onMerge(value:IAction):void {
			_onMerge = value;
		}
		
		public function doAction(grid:TreeGrid):void 
		{
			var prevTime:int = getTimer();
			
			var toMerge:Iset = grid.getIsetById(_mergeId);
			if (toMerge != null) 
			{
				var base:Iset = grid.getIsetById(_baseId);
				if (base == null) {
					grid.mergeBase = toMerge;
				} else {					
					base.merge(toMerge);
					_onMerge.doAction(grid);					
					grid.mergeBase = null;					
				}
			} else {
				grid.mergeBase = null;	
			}			
			
			grid.orderIds();
			
			_timeElapsed = getTimer() - prevTime;
		}
		
		public function get changesData():Boolean {
			return _baseId >= 0 && _mergeId >= 0;
		}
		
		public function get changesSize():Boolean {
			return _baseId >= 0 && _mergeId >= 0;
		}
		
		public function get changesDisplay():Boolean {
			return true;
		}
	}
}