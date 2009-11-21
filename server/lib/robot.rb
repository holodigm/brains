require 'rest_client'
require 'timeout'
require 'benchmark'

class Robot < Actor

  class ExhaustedError < RuntimeError; end
  class ActionParseError < RuntimeError; end

  VALID_ACTIONS = %w(idle move attack turn)
  MAX_LENGTH = 256
  TIMEOUT = 100

  EXPENSES = {
    :idle => 20,
    :move => -5,
    :turn => -30,
    :attack => -100
  }

  SPAWN_BOX = 0.8 # %

  attr_accessor :brain, :energy, :name, :exception

  def self.place(width, height)
    x_variance = width * (SPAWN_BOX/2)
    x = rand(-x_variance, x_variance) + width / 2
    y_variance = height * (SPAWN_BOX/2)
    y = rand(-y_variance, y_variance) + height / 2
    [x, y]
  end

  def self.new_with_brain(url, name)
    returning(new) do |h|
      h.brain = RestClient::Resource.new(url, :timeout => TIMEOUT, :open_timeout => TIMEOUT)
      h.name = name
      h.brain
    end
  end
  
  def run
    Thread.new do
      while true
        think world.current_environment_for(self)
        sleep 0.5
      end
    end
  end

  def initialize
    super
    self.energy = 100
    self.score = 0
  end

  def think(env)
    puts "#{name} Thinking"
    response = brain.post(env.to_json)
    puts "#{name} Got response #{response}"
    valid_response = validate(response)
    action = parse_action(valid_response)
    world.mutex.synchronize { update(action) }
  rescue Timeout::Error
    logger.info("#{name} timed out")
    hurt(10)
    rest
  end

  def decays
    self.decay += 2
  end

  def to_hash
    returning(super.merge({:name => name, :energy => energy, :score => score})) do |h|
      h[:exception] = exception if exception
    end
  end

# vars

  def damage; 30 + rand(0,30) end
  def range; 200 end
  def eyesight; 200 end

# private

   def work(task)
     amount = EXPENSES[task]
     (energy < -amount) ? raise(ExhaustedError) : add_energy(amount)
   end
   
   def add_energy(amount)
     if energy < 500
       self.energy += amount
     end
   end

  def validate(response)
    if response.code != 200 || response.length > MAX_LENGTH
      raise RestClient::Exception
    else
      response
    end
  end

  def parse_action(response)
    returning(JSON.parse(response)) do |j|
      { 'action' => lambda {|action| VALID_ACTIONS.include?(action)},
        'x' => lambda {|x| (-1..1).include?(x)},
        'y' => lambda {|y| (-1..1).include?(y)},
        'dir' => lambda {|dir| dir.is_a?(Numeric)}
      }.each do |key, validator|
        raise ActionParseError if j[key] && !validator.call(j[key])
      end
    end
  end

  def update(action)
    case action['action']
    when 'idle'
      work(:idle)
      rest
    when 'move'
      work(:move)
      move(action['x'], action['y'])
    when 'turn'
      work(:turn)
      turn(action['dir'])
    when 'attack'
      work(:attack)
      attack
    end
  # rescue World::SteppingOnToesError => e, ExhausedError => e
  #   self.exception = e.name
  rescue World::SteppingOnToesError
    self.exception = 'SteppingOnToesError'
    rest
  rescue ExhaustedError
    self.exception = 'ExhaustedError'
    rest
  end

end
