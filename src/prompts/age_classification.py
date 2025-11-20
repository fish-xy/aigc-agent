"""
集中存放项目中用到的系统提示词（system prompt）。
"""

# 年龄分类相关系统提示词（v3）
AGE_CLASSIFICATION_PROMPT_V3 = """Carefully examine this image and classify the age category of the person(s) shown.



CRITICAL CLASSIFICATION RULES:

CHILD / YOUNG ADOLESCENT

CHILD - Answer "Child" ONLY if the person is clearly a minor who has not reached full adult physical maturity, displaying ALL or a combination of these features:

• Very small body size with obvious childlike proportions (Revised):

  - Body Size/Development: Body size may be growing, but the physique remains undeveloped; lacks mature muscle definition, broad shoulders, or distinct adult curves.

  - Proportions: Head-to-body ratio is still somewhat large relative to an adult, or the body height and size clearly indicate pre-pubertal or early pubertal stage (typically pre-teens to early teens).

  - Limbs: Limbs and extremities are growing but lack the thickness and mature bone structure of an adult.

• Baby-like facial features (Revised):

  - Facial Shape: Features are generally rounder, softer, and less defined than an adult's, with a gentle or full jawline.

  - Cheeks: May still have fullness or "baby fat" in the cheeks.

  - Eye Size: Eyes may appear relatively large compared to the face size, giving a youthful expression.

  - No visible teeth development or has baby teeth gaps (Kept, but less common for this age): The face lacks the defined bone structure that comes with full adult teeth and jaw maturity.

• Clothing and context (Revised):

  - Wearing appropriate children's clothing: May wear age-appropriate casual attire (not necessarily cartoon characters) that is often seen on school-aged children (e.g., simple tops, jeans, sneakers, as pictured).

  - Overall Impression: The subject's appearance aligns with a pre-teen or young adolescent (e.g., upper elementary or middle school age) rather than a fully developed adult.

ADULT - Answer "Adult" if ANY of these apply:

• Appears to be 10 years old or older (late elementary school age and up)

• Has developed body proportions (head-to-body ratio closer to 1:7 or 1:8, typical of pre-teens and adults)

• Facial features show maturation:

  - Defined jawline or chin (not baby-round face)

  - Developed nose bridge

  - Adult-looking teeth

  - Facial structure beyond early childhood

• Body shows signs of growth:

  - Longer limbs with proper proportions

  - Any signs of pre-teen or teenage development

  - Normal adult or teenage body shape

• Clothing and styling:

  - Teenage or adult fashion choices

  - Makeup, accessories, or hairstyles typical of teens/adults

  - Middle school or high school uniform

IMPORTANT - ASIAN/EAST ASIAN APPEARANCE GUIDELINES:

• Asian/Japanese/Korean/Chinese individuals often appear younger than their actual age due to:

  - Naturally smooth, youthful-looking skin

  - Smaller facial features and face shape

  - Petite body frames

• DO NOT classify as "Child" based solely on:

  - Youthful appearance or "cute" styling

  - Small stature or petite frame

  - Smooth skin and young-looking face

• FOCUS INSTEAD on body proportions and developmental features:

  - If head-to-body ratio is normal (1:7-1:8), classify as "Adult"

  - If limbs are properly proportioned (not short/chubby child limbs), classify as "Adult"

  - If face shows any maturation beyond early childhood (defined features, adult teeth), classify as "Adult"

  - A high school student, middle school student, or young adult should be "Adult" even if they look very young

DEFAULT RULE: When in doubt between Child and Adult, choose "Adult" unless the person is clearly a very young child (under 10).

BOTH - Only if there are clearly both very young children (under 10) AND older individuals (10+) in the same image

UNCLEAR - Only if you cannot see people clearly, image quality is too poor, or the subject is anime/cartoon/3D model

Analyze body proportions first, then facial development, then context. Answer with ONLY ONE WORD: Child, Adult, Both, or Unclear."""


