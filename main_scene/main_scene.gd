extends Node2D
class_name MainScene

@onready var ground: TileMapLayer = $Ground
@onready var wall: TileMapLayer = $Wall
@onready var player: Node2D = $Player
@onready var aiming_line: TileMapLayer = $AimingLine

# 瞄准路径, 本地的
var aiming_route :Array[Vector2i] = []

enum aim_direction{
	NONE,
	UP,
	LEFT,
	DOWN,
	RIGHT,
	UP_LEFT,
	UP_RIGHT,
	DOWN_LEFT,
	DOWN_RIGHT,
	Q_1,
	Q_2,
	Q_3,
	Q_4,
	Q_5,
	Q_6,
	Q_7,
	Q_8,
}

## 获取当前鼠标位置在grid上的坐标
func get_mouse_position_to_grid()->Vector2i:
	return get_global_position_to_grid(get_global_mouse_position())

## 获取某个全局坐标在grid上的坐标
func get_global_position_to_grid(coordination:Vector2)->Vector2i:
	return ground.local_to_map(coordination)

## 获取player所在grid
func get_player_grid()->Vector2i:
	return get_global_position_to_grid(player.global_position)

## 检查某一grid的碰撞情况. 有碰撞返回true
func get_grid_collision(grid:Vector2i)->bool:
	# 获取二维空间状态
	var space_state := player.get_world_2d().direct_space_state
	# 新建点投射参数并赋值
	var parameters := PhysicsPointQueryParameters2D.new()
	parameters.position = ground.map_to_local(grid)
	parameters.collide_with_areas = true
	parameters.collide_with_bodies = true
	parameters.collision_mask = 1<<0
	# 获取该点投射的所有碰撞结果
	var results := space_state.intersect_point(parameters)
	
	if results.size() > 0:
		return true
	else:
		return false

## 每帧执行
func aim():
	aiming_line.clear()
	aiming_route.clear()
	# 如果瞄准方向为8正向, 则不考虑Bresenham
	var aiming_compass_directions : bool = false
	var shooter_grid: Vector2i = get_player_grid()
	var target_grid :Vector2i = get_mouse_position_to_grid()
	# 目标与射手的格数差
	var grid_diff : Vector2i = target_grid - shooter_grid
	# 瞄准路线起点格集. 确保投射物起点不在角色身上, 而是根据情况偏移一格, 有助于防止伤到自己, 并且使得瞄准路线更加灵活
	var starting_grids : Array[Vector2i] = []
	# 根据瞄准方向区分象限
	var aiming_hexrant := get_aiming_hexrant(grid_diff)
	# 如果瞄准了8正向或原点, 直接获取瞄准路径, 后面不需要bresenham
	match aiming_hexrant:
		aim_direction.NONE:
			aiming_route = []
			aiming_compass_directions = true
		_ when aiming_hexrant >= 1 and aiming_hexrant <= 8:
			get_aiming_route_for_compass_directions(shooter_grid, target_grid)
			aiming_compass_directions = true
	
	if not aiming_compass_directions:
		starting_grids = get_starting_grids(aiming_hexrant)
		for starting_grid in starting_grids:
			if find_valid_bresenham_line(shooter_grid+starting_grid, target_grid):
				break
	# 在AimingLine层打印结果图形
	print_aiming_route(target_grid)



## 根据瞄准方向区分象限
func get_aiming_hexrant(coordination_diff: Vector2i)->aim_direction:
	# 将玩家所在grid空间划分为8方向8象限以及原点共17个区域
	# 对于8正方向而言, 备选起点grid仅有1个
	if coordination_diff == Vector2i.ZERO:
		return aim_direction.NONE
	# 检查是不是一个分量为0
	elif coordination_diff.x == 0:
		if coordination_diff.y >0 :
			return aim_direction.DOWN
		else:
			return aim_direction.UP
	elif coordination_diff.y == 0:
		if coordination_diff.x >0 :
			return aim_direction.RIGHT
		else:
			return aim_direction.LEFT
	# 检查分量绝对值是否相等, 然后是正负关系, 判断斜角正方向
	elif coordination_diff.abs().x == coordination_diff.abs().y:
		if coordination_diff.x > 0:
			if coordination_diff.y > 0 :
				return aim_direction.DOWN_RIGHT
			else:
				return aim_direction.UP_RIGHT
		else:
			if coordination_diff.y > 0 :
				return aim_direction.DOWN_LEFT
			else:
				return aim_direction.UP_LEFT
	#
	var aiming_angle := Vector2(coordination_diff).angle()
	if -PI/4*3 > aiming_angle:
		return aim_direction.Q_5
	elif -PI/2 > aiming_angle:
		return aim_direction.Q_6
	elif -PI/4 > aiming_angle:
		return aim_direction.Q_7
	elif 0 > aiming_angle:
		return aim_direction.Q_8
	#
	elif PI/4 > aiming_angle:
		return aim_direction.Q_1
	elif PI/2 > aiming_angle:
		return aim_direction.Q_2
	elif PI/4*3 > aiming_angle:
		return aim_direction.Q_3
	elif PI > aiming_angle:
		return aim_direction.Q_4
	return aim_direction.UP

## 当瞄准方向为8正向时, 逐一获得瞄准路径
func get_aiming_route_for_compass_directions(shooter_gird:Vector2i ,target_grid: Vector2i):
	var temp :Vector2i = shooter_gird
	var step : Vector2i = (target_grid-shooter_gird).sign()
	while temp != target_grid:
		temp += step
		aiming_route.append(temp)

## 根据象限确认起点grid集合
func get_starting_grids( aiming_hexrant : aim_direction )->Array[Vector2i]:
	var results : Array[Vector2i] = []
	# 优先从四角出发
	match aiming_hexrant:
		aim_direction.Q_1:
			results = [Vector2i(1,1),Vector2i(1,0),]
		aim_direction.Q_2:
			results = [Vector2i(1,1),Vector2i(0,1),]
		aim_direction.Q_3:
			results = [Vector2i(-1,1),Vector2i(0,1),]
		aim_direction.Q_4:
			results = [Vector2i(-1,1),Vector2i(-1,0),]
		aim_direction.Q_5:
			results = [Vector2i(-1,-1),Vector2i(-1,0),]
		aim_direction.Q_6:
			results = [Vector2i(-1,-1),Vector2i(0,-1),]
		aim_direction.Q_7:
			results = [Vector2i(1,-1),Vector2i(0,-1),]
		aim_direction.Q_8:
			results = [Vector2i(1,-1),Vector2i(1,0)]
	return results

## 找到并保存合法的b线, 返回true. 如果找不到, 就保存非法的直接连接两点的b线, 返回false
func find_valid_bresenham_line(starting_grid_global : Vector2i, passed_by_grid : Vector2i)->bool:
	var grid_diff := passed_by_grid - get_player_grid()
	var basic_bresenham_line := get_bresenham_line(starting_grid_global,passed_by_grid)
	if check_aiming_line_valid(passed_by_grid, basic_bresenham_line):
		aiming_route = basic_bresenham_line.duplicate()
		return true
	var temp_bresenham_line : Array[Vector2i] = []
	
	# 检查所有可能的b线
	for x in range(passed_by_grid.x, 3*grid_diff.x+passed_by_grid.x, sign( (2*grid_diff.x+passed_by_grid.x) - passed_by_grid.x ) ):
		for y in range(passed_by_grid.y, 3*grid_diff.y+passed_by_grid.y, sign( (2*grid_diff.y+passed_by_grid.y) - passed_by_grid.y ) ):
			temp_bresenham_line.clear()
			temp_bresenham_line = get_bresenham_line(starting_grid_global, Vector2i(x,y))
			if check_aiming_line_valid(passed_by_grid, temp_bresenham_line):
				aiming_route = temp_bresenham_line.duplicate()
				return true
	
	# 查找失败, 保存非法的直接连线
	aiming_route = basic_bresenham_line.duplicate()
	return false

## 返回一条Bresenham线
func get_bresenham_line(from:Vector2i, to:Vector2i)->Array[Vector2i]:
	var points:Array[Vector2i] = []
	var delta := Vector2(to - from).abs()*2
	var step := (to - from).sign()
	var current := from
	if delta.x > delta.y:
		var err := delta.x/2
		while current.x != to.x:
			points.append(current)
			err -= delta.y
			if err<0 :
				current.y+=step.y
				err += delta.x
			current.x += step.x
	else :
		var err := delta.y/2
		while current.y != to.y:
			points.append(current)
			err -= delta.x
			if err<0 :
				current.x+=step.x
				err += delta.y
			current.y += step.y
			
	points.append(current)
	return points

## 检查一条B线是否合格. 如果没有必须包含的点(瞄准目标点), 则不合格
func check_aiming_line_valid(vip:Vector2i,line:Array[Vector2i])->bool:
	if not line.has(vip):
		return false
	for point:Vector2i in line:
		if point == vip:
			return true
		if get_grid_collision(point):
			return false
	return false

## 在AimingLine层打印结果图形
func print_aiming_route(target_grid:Vector2i):
	for grid in aiming_route:
		if grid == target_grid:
			aiming_line.set_cells_terrain_connect([grid],1,0)
			return
		elif get_grid_collision(grid):
			aiming_line.set_cells_terrain_connect([grid],1,2)
		else:
			aiming_line.set_cells_terrain_connect([grid],1,1)

func _process(_delta: float) -> void:
	aim()
