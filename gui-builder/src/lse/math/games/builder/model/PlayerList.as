package lse.math.games.builder.model 
{	

	import mx.collections.ArrayList; 
	
	//@TODO: Make sure chance player is at index 0. 
	public class PlayerList
	{
		
		private var MAX_PLAYERS : int = 4;
		
		private var _pList: ArrayList;
	
		public function PlayerList()
		{
			_pList = new ArrayList();
		}
		
		
		public function add(p:Player) : void
		{
			_pList.addItem(p);
		}
		
		public function remove(p: Player) : void
		{
			_pList.removeItem(p);
		}
		
		public function clear() : void
		{
			_pList.removeAll();
		}
		
		public function size() : int
		{
			return _pList.length;
		}
		
		public function get(index : int) : Player
		{
			return Player(_pList.getItemAt(index));
			
		}
	
		public function toString() : String
		{
			var ret:String = "List of Players: \n";
		
			for(var p:String in _pList)
			{
				ret += p;
				ret += "\n";
			}
			
			return ret;
		}
		public function get playerList():ArrayList {return _pList;}
		
	}
}
