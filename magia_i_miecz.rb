# encoding: utf-8

require "bundler/setup"
require "gaminator"

class MagiaIMiecz

  class Player < Struct.new(:x, :y)
    attr_accessor :strength, :endurance, :temp_strength

    def initialize(x,y)
      @endurance = 4
      @strength = 5
      @temp_strength = 0
    end

    def receive_hit( hit = 1 )
      @endurance -= hit
    end

    def char
      "@"
    end
    
    def color
      Curses::COLOR_RED
    end
  end

  class Item < Struct.new(:x, :y)
    
    def initialize(x, y, char)
      self.x = x
      self.y = y
      @char = char
    end

    def char
     @char
    end

  end


  class Map < Hash

    TILES = [
      { :x =>  11, :y =>  8, :can_win =>  false },
      { :x =>  42, :y =>  3, :can_win =>  false },
      { :x =>  78, :y =>  6, :can_win =>  false },
      { :x =>  133, :y =>  8, :can_win =>  false },
      { :x =>  131, :y =>  21, :can_win =>  false },
      { :x =>  132, :y =>  26, :can_win =>  false },
      { :x =>  135, :y =>  42, :can_win =>  false },
      { :x =>  87, :y =>  46, :can_win =>  false },
      { :x =>  60, :y =>  46, :can_win =>  true },
      { :x =>  10, :y =>  42, :can_win =>  false },
      { :x =>  8, :y =>  27, :can_win =>  false },
      { :x =>  15, :y =>  19, :can_win =>  false },
    ]

    MONSTERS = [
      { :name => "Żygacz", :strength => 5, :text => "Ohydny Żygacz sieje spustoszenie w tej okolicy, pozostanie tu aż ktoś go pokona", :lose=> "Pokonałeś Żygacza.", :win => "Żygacz okazał się lepszy.", :equal => "Remis. Żygacz nie został pokonany." },
      { :name => "Dzik", :strength => 1, :text => "Ogromny dzik włóczy się po tej okolicy", :lose=> "Pokonałeś Dzika", :win => "Dzik okazał się lepszy.", :equal => "Remis. Dzik  nie został pokonany." },
      { :name => "Smok", :strength => 7, :text => "Od pewnego czasu tę okolicę terroryzuje smok. Jeśli nie masz dziewicy musisz walczyć!", :lose=> "Plugawa besta jest nabita na Twą dzidę.", :win => "Skok zieje Ci w twarz! Ledwo uchodzisz z żywiem.", :equal => "Smok i Ty wycofujecie się." },
      { :name => "Wataha wilków", :strength => 5, :text => "Otacz Cię wataha wilków.", :lose=> "Pokonałeś samca alfa. Wataha ucieka.", :win => "Zostałeś otoczony i pogryziony.", :equal => "Wycofujecie się delikatnie." }
    ]

    def initialize( player )
      @text = ""
      @chars = {}
      @objects = []
      @player = player
      @actual_tile = 0
      self.load_map
      move_right(0)
    end

    def tile_description
      @text + " --- Siła: #{@player.strength} - Wytrzymałość: #{@player.endurance}"
    end

    def fight
      monster = MONSTERS[rand(MONSTERS.length)]
      @text = monster[:text] + "\n"
      monster_result = monster[:strength] + rand(6) + 1
      player_result = @player.strength + rand(6) + 1

      if monster_result > player_result
        @player.endurance -= 1
        @text += monster[:win]
      elsif player_result > monster_result
        @player.temp_strength += monster[:strength]
        if( @player.temp_strength > 7 )
          @player.strength += 1
          @player.temp_strength = 0
        end
        @text += monster[:lose]
      else
        @text +=  monster[:equal]
      end
    end

    def move_left( pick_result )
      @actual_tile -= pick_result
      actual_tile = self.get_tile_point()
      @player.x = actual_tile[:x]
      @player.y = actual_tile[:y]
      fight
    end

    def move_right( pick_result )
      @actual_tile += pick_result
      actual_tile = self.get_tile_point()
      @player.x = actual_tile[:x]
      @player.y = actual_tile[:y]
      fight
    end

    def move_up?
      can_win = get_tile_point[:can_win]
      if can_win
        @player.y = 26
        @player.x = 66
      end
      can_win
    end

    def get_tile_point
      if( @actual_tile < 0 )
        @actual_tile += TILES.length
      elsif @actual_tile >= TILES.length
        @actual_tile -= TILES.length
      end

      TILES[@actual_tile]
    end

    def set_char(x, y, char)
      self[x] = {} unless self[x]
      self[x][y] = char
    end

    def get_actual_tile
      @actual_tile
    end

    def load_map
      file = File.open( 'mapa.txt' )
      y = 0

      file.each_line do |line|
        x = 0

        line.chomp.each_char do |char|
          if TILES.select { |f| ( f[:x] == x or f[:x] == 66 ) and ( f[:y] == y or f[:y] == 26 ) }.length == 0
            item = Item.new(x, y, char)
            set_char(x, y, item)
            @objects.push(item)
          end

          x += 1
        end

        y += 1
      end

    end

    def objects
      @objects
    end

  end

  def initialize(width, height)
    @win = false
    @pick_result = 0
    @actual_tile = 0
    @width = width
    @height = height

    @player = Player.new(0,0)
    @map = Map.new( @player )
  end

  def objects
    [@player] + @map.objects
  end

  def input_map
    {
      ?q => :exit,
      ?h => :move_left,
      ?l => :move_right,
      ?k => :move_up,
    }
  end
  
  def move_left
    @map.move_left(@pick_result)
    @pick_result = 0
  end

  def move_right
    @map.move_right(@pick_result)
    @pick_result = 0
  end

  def move_up
    if @map.move_up?
      @win = true
    end
  end

  def tick
    throw_a_pick
    if @player.endurance <= 0 
      exit
    end
  end

  def sleep_time
    0.1
  end

  def wait?
    @pick_result > 0 or @win
  end

  def textbox_content
    if @win
      "Wygrałeś"
    else
      @map.tile_description
    end
  end

  def exit_message
    "Game over"
  end

  def exit
    Kernel.exit
  end

  private

  def throw_a_pick
    @pick_result = rand(6) + 1 if @pick_result == 0
  end
end

Gaminator::Runner.new(MagiaIMiecz, rows: 55, cols: 150).run
