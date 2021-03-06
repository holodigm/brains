require 'uuid'

class Actor
  include States

  attr_accessor :x, :y, :dir, :health, :decay, :score

  states :idle, :moving, :turning, :attacking, :dead

  def initialize
    self.state, self.x, self.y, self.dir, self.health = :idle, 0, 0, 0, 100
    self.decay = 0
    self.score = 0
  end

  def id
    @id ||= ['brains/actor/', UUID.new.generate].join
  end

  def rest
    changes :from => being_alive, :to => :idle
  end

  def move(dx,dy)
    world.try_to_place(self, x+dx, y+dy)
    changes :from => being_alive, :to => :moving
  end

  def attack
    self.score += world.attack_from(self)
    changes :from => being_alive, :to => :attacking
  end

  def turn(deg)
    self.dir = deg
    changes :from => being_alive, :to => :turning
  end

  def kill!
    self.health = -1
    changes :from => being_alive, :to => :dead
  end

  def dir=(dir)
    # TODO Investigate
    @dir = (dir || 0) % 360
  end

  def hurt(amount)
    (self.health <= amount) ? kill! : self.health -= amount
  end

  def decays
    self.decay += 1
  end

  def can_see?(actor)
    self != actor && in_cone?(actor, 60, eyesight)
  end

  def can_attack?(victim)
    self != victim && !victim.dead? && in_cone?(victim, 2, range)
  end

  def to_hash
    {:state => state, :x => x, :y => y, :dir => dir,
     :type => self.class.name.downcase, :health => health, :decay => decay,
     :id => id}
  end

  def to_json
    to_hash.to_json
  end

# private

  def being_alive
    [:idle, :moving, :turning, :attacking]
  end

  def distance(x,y)
    Math.hypot(x-self.x, y-self.y)
  end

  def distance_to(actor)
    distance(actor.x, actor.y) rescue 0
  end

  def direction_to(actor)
    (Math.atan2(x - actor.x, y - actor.y).to_deg + 180) % 360 rescue 0
  end

  def in_cone?(obj, alpha, r)
    (direction_to(obj)-dir).abs < alpha && distance_to(obj) <= r
  end

  def self.clean_writer(*attrs)
    attrs.each do |attr|
      instance_eval <<-METHOD
        def #{attr}(val=nil, &block)
          if val || block_given?
            @#{attr} = val || block
          else
            @#{attr}.is_a?(Proc) ? @#{attr}.call : @#{attr}
          end
        end
      METHOD
      define_method(attr) { self.class.send(attr) }
    end
  end

end


