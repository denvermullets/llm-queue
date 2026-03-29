class OcrService
  class OcrError < StandardError; end

  def initialize(base64_image)
    @base64_image = strip_base64_prefix(base64_image)
  end

  def extract_text
    tempfile = Tempfile.new(['ocr', '.png'])
    tempfile.binmode
    tempfile.write(Base64.decode64(@base64_image))
    tempfile.close

    result = RTesseract.new(tempfile.path)
    text = result.to_s.strip

    raise OcrError, 'No text extracted from image' if text.empty?

    text
  ensure
    tempfile&.unlink
  end

  private

  def strip_base64_prefix(str)
    str.sub(%r{^data:image/[^;]+;base64,}, '')
  end
end
