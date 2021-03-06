class UserCurrentRole < ActiveRecord::Base
  include AdmRegionDelegation

  belongs_to :current_role
  belongs_to :nomination_source
  belongs_to :region    # a.k.a adm_region_id
  belongs_to :uic, :inverse_of => :user_current_roles
  belongs_to :user, inverse_of: :user_current_roles

  validates :current_role, :nomination_source, presence: true
  validates_uniqueness_of :current_role_id, :scope => [:user_id, :uic_id]
  validate :validate_legitimacy
  validate :validate_tic_uic

  delegate :number, :to => :uic, :prefix => true, :allow_nil => true

  before_save :set_region_from_user
  after_save :update_uic_participants_count
  after_destroy :update_uic_participants_count

  scope :dislocatable, proc { joins(:current_role).merge(CurrentRole.dislocatable) }

  def uic_number=(number)
    self.uic = number.presence && Uic.find_by_number(number)
  end

  delegate :priority, :to => :current_role, :prefix => true
  delegate :must_have_tic?, :must_have_uic?, :to => :current_role, :allow_nil => true

  # it's better to move it to UserCurrentRole decorator
  def selectable_uics
    set_region_from_user
    return [] unless region
    uics = region.uics_with_nested_regions.order(:name)
    uics = region.adm_region.uics_with_nested_regions.order(:name) if uics.blank? && region.adm_region
    if must_have_tic?
      uics.tics
    elsif must_have_uic?
      uics.uics
    else
      uics
    end
  end

  private

  def validate_tic_uic
    return unless current_role.present?
    errors.add(:uic, :blank) if must_have_tic? && !uic.try(:tic?)
    errors.add(:uic, :blank) if must_have_uic? && !uic.try(:uic?)
  end

  def validate_legitimacy
    return unless current_role.present? && nomination_source.present?
    case current_role.slug
    when 'journalist'
      if nomination_source.variant != 'media'
        errors.add(:nomination_source, :incorrect_nomination_source)
      end
    end
  end

    def update_uic_participants_count
      Uic.find_by(:id => uic_id_was).try(:update_participants_count!) if uic_id_changed?
      uic.try(:update_participants_count!)
    end

    def set_region_from_user
      if user
        self.region ||= (user.region || user.adm_region)
      end
    end

end
