import base64
import json
import logging
import requests
from django.conf import settings

logger = logging.getLogger(__name__)

def scan_receipt_with_gemini(image_bytes, mime_type):
    """
    Sends receipt image bytes to Gemini 1.5 Flash API to extract itemized lines.
    Returns:
        List of dicts: [{'name': str, 'price': float, 'quantity': int}]
    """
    api_key = getattr(settings, "GEMINI_API_KEY", "")
    if not api_key:
         raise ValueError("GEMINI_API_KEY is not configured on the server.")

    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={api_key}"
    
    # Base64 encode the image
    image_b64 = base64.b64encode(image_bytes).decode('utf-8')
    
    prompt = (
        "Распознай чек на фотографии. Верни результат строго в формате JSON, без каких-либо markdown-разметки типа ```json или текста вокруг. "
        "JSON должен быть списком объектов с ключами: "
        "'name' (название позиции, очищенное от лишних символов типа кодов/номеров/разделителей), "
        "'price' (суммарная цена за позицию в виде числа с плавающей точкой), "
        "'quantity' (количество товара в виде числа). "
        "Пример ответа:\n"
        "[{\"name\": \"Суп Солянка\", \"price\": 300.0, \"quantity\": 1}, {\"name\": \"Пиво\", \"price\": 450.0, \"quantity\": 3}]\n"
        "Распознавай только позиции чека (блюда, товары, услуги). Проигнорируй метаданные типа кассира, даты, ИНН, скидок или итоговой суммы."
    )
    
    payload = {
        "contents": [{
            "parts": [
                {"text": prompt},
                {
                    "inlineData": {
                        "mimeType": mime_type,
                        "data": image_b64
                    }
                }
            ]
        }]
    }
    
    logger.info("Sending receipt image to Gemini 1.5 Flash API...")
    response = requests.post(url, json=payload, headers={"Content-Type": "application/json"}, timeout=30)
    response.raise_for_status()
    result = response.json()
    
    try:
        text_response = result['candidates'][0]['content']['parts'][0]['text']
        # Remove potential markdown wraps if the model did not follow the instructions strictly
        cleaned_text = text_response.strip()
        if cleaned_text.startswith("```json"):
            cleaned_text = cleaned_text[7:]
        if cleaned_text.endswith("```"):
            cleaned_text = cleaned_text[:-3]
        cleaned_text = cleaned_text.strip()
        
        parsed = json.loads(cleaned_text)
        if not isinstance(parsed, list):
            raise ValueError("Gemini response is not a JSON list of items.")
        return parsed
    except Exception as e:
        logger.error(f"Failed to parse Gemini response: {e}. Raw response: {result}")
        raise ValueError(f"Ошибка парсинга ответа нейросети: {e}")
