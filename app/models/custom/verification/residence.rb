require_dependency Rails.root.join("app", "models", "verification", "residence").to_s

class Verification::Residence
  validate :local_postal_code
  validate :local_residence

  def local_postal_code
    errors.add(:postal_code, I18n.t("verification.residence.new.error_not_allowed_postal_code")) unless valid_postal_code?
  end

  def local_residence
    return if errors.any?

    unless residency_valid?
      errors.add(:local_residence, false)
      store_failed_attempt
      Lock.increase_tries(user)
    end
  end

  private

    def retrieve_census_data
      # Empty method because we don't check against census
    end

    def allowed_postal_code
      errors.add(:postal_code, I18n.t("verification.residence.new.error_not_allowed_postal_code")) unless valid_postal_code?
    end

    def valid_postal_code?
      Zipcode.where(code: postal_code&.upcase).any?
    end

    def document_number_uniqueness_if_present
      if document_number.present?
        document_number_uniqueness
      end
    end
end
